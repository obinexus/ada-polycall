--  ada-polycall tests against the REAL installed libpolycall (no mock).
--
--    ada_polycall_test <repo-root>
--
--  Covers the checklist of the core's docs/BINDING_ABI.md through the Ada
--  API (Ada tasks for cancel/close/concurrency). Checks that need the C CLI
--  read POLYCALL_CLI, POLYCALL_CLI_PEER, POLYCALL_RPC_ENDPOINT and
--  POLYCALL_DEV_TOKEN (tests/run-real.sh starts the CLI nodes); without
--  them they print SKIP, never PASS. Exit status 1 on any FAIL.

with Ada.Calendar;
with Ada.Command_Line;
with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Interfaces;
with Interfaces.C;
with Ada_Polycall;

procedure Ada_Polycall_Test is
   use Ada.Strings.Unbounded;
   use Ada.Text_IO;
   use Ada_Polycall;
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Streams.Stream_Element_Array;
   use type Ada.Calendar.Time;

   Passed, Failed, Skipped : Natural := 0;

   procedure Check (OK_Cond : Boolean; Name : String; Detail : String := "")
   is
   begin
      if OK_Cond then
         Passed := Passed + 1;
         Put_Line ("PASS " & Name);
      else
         Failed := Failed + 1;
         Put_Line ("FAIL " & Name & (if Detail = "" then "" else " -- " & Detail));
      end if;
   end Check;

   procedure Skip (Name, Reason : String) is
   begin
      Skipped := Skipped + 1;
      Put_Line ("SKIP " & Name & " -- " & Reason);
   end Skip;

   function Img (V : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (V), Ada.Strings.Left));

   procedure Expect (Want, Got : Status_Code; Name : String; Detail : String := "") is
   begin
      Check (Want = Got, Name,
             "expected " & Img (Want) & " got " & Img (Got) & " " & Detail);
   end Expect;

   function Contains (Hay, Needle : String) return Boolean is
     (Ada.Strings.Fixed.Index (Hay, Needle) > 0);

   function Env (Name : String) return String is
     (if Ada.Environment_Variables.Exists (Name)
      then Ada.Environment_Variables.Value (Name) else "");

   function C_System (Command : Interfaces.C.char_array) return Interfaces.C.int
     with Import, Convention => C, External_Name => "system";

   function Run (Command : String) return Integer is
     (Integer (C_System (Interfaces.C.To_C (Command))));

   function Slurp (Path : String) return String is
      F      : File_Type;
      Result : Unbounded_String;
   begin
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         Append (Result, Get_Line (F));
      end loop;
      Close (F);
      return To_String (Result);
   exception
      when others => return "";
   end Slurp;

   function Base64 (B : Bytes) return String is
      T : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      R : Unbounded_String;
      I : Ada.Streams.Stream_Element_Offset := B'First;
      V : Natural;
   begin
      while I + 2 <= B'Last loop
         V := Natural (B (I)) * 65536 + Natural (B (I + 1)) * 256 + Natural (B (I + 2));
         Append (R, T (V / 262144 + 1) & T (V / 4096 mod 64 + 1)
                    & T (V / 64 mod 64 + 1) & T (V mod 64 + 1));
         I := I + 3;
      end loop;
      if I = B'Last then
         V := Natural (B (I)) * 65536;
         Append (R, T (V / 262144 + 1) & T (V / 4096 mod 64 + 1) & "==");
      elsif I + 1 = B'Last then
         V := Natural (B (I)) * 65536 + Natural (B (I + 1)) * 256;
         Append (R, T (V / 262144 + 1) & T (V / 4096 mod 64 + 1)
                    & T (V / 64 mod 64 + 1) & "=");
      end if;
      return To_String (R);
   end Base64;

   Root : constant String :=
     (if Ada.Command_Line.Argument_Count > 0
      then Ada.Command_Line.Argument (1) else ".");

   ---------------------------------------------------------------------------

   procedure Test_Version is
      Name : constant String := Error_Name (E_Timeout);
   begin
      Check (ABI_Version = 1, "abi: ABI_Version = 1");
      begin
         Check_ABI;
         Check (True, "abi: Check_ABI accepts the library");
      exception
         when E : Polycall_Error =>
            Check (False, "abi: Check_ABI accepts the library",
                   Ada.Exceptions.Exception_Message (E));
      end;
      Check (Version'Length >= 5 and then Version (Version'First .. Version'First + 1) = "1."
             and then Version >= "1.1.0", "version: library >= 1.1.0", Version);
      Check (Name'Length >= 18 and then Name (Name'First .. Name'First + 17) = "POLYCALL_E_TIMEOUT",
             "strerror names E_TIMEOUT", Name);
      Check (Contains (Error_Name (-999), "POLYCALL_E_UNKNOWN"), "strerror of an unknown code");
   end Test_Version;

   procedure Test_Run_Config is
      Fx : constant String := Root & "/tests/fixtures/";
      S  : Status_Code := OK;
   begin
      Expect (OK, Run_Config (Root & "/ada-polycallrc"), "run_config: shipped ada-polycallrc (run=1)");
      Expect (OK, Run_Config (Root & "/ada-polycallrc", Strict => False), "run_config: valid, validate-only");
      Expect (OK, Run_Config (Root & "/examples/ada-polycallrc"), "run_config: examples/ada-polycallrc");
      begin
         Run_Config_Or_Raise (Fx & "does-not-exist");
         Check (False, "run_config: missing -> E_NOT_FOUND", "no exception");
      exception
         when E : Polycall_Error =>
            declare
               Msg : constant String := Ada.Exceptions.Exception_Message (E);
            begin
               Expect (E_Not_Found, Status_Of (E), "run_config: missing -> E_NOT_FOUND");
               Check (Contains (Msg, "POLYCALL_E_NOT_FOUND") and Contains (Msg, "does-not-exist"),
                      "Polycall_Error carries status name + last_error detail", Msg);
            end;
      end;
      Expect (E_Config, Run_Config (Fx & "invalid-polycallrc", Strict => False),
              "run_config: malformed -> E_CONFIG (validate)");
      Expect (E_Config, Run_Config (Fx & "invalid-polycallrc", Strict => True),
              "run_config: malformed -> E_CONFIG (strict)");
      Expect (OK, Run_Config (Fx & "unknown-key-polycallrc", Strict => False),
              "run_config: unknown key warns when validating");
      Expect (E_Config, Run_Config (Fx & "unknown-key-polycallrc", Strict => True),
              "run_config: unknown key fails when strict");
      Expect (OK, Run_Config (Fx & "tls-polycallrc", Strict => False),
              "run_config: tls_enabled=true validates");
      Expect (E_Unsupported, Run_Config (Fx & "tls-polycallrc", Strict => True),
              "run_config: tls strict -> E_UNSUPPORTED");
      Expect (E_Invalid_Argument, Run_Config ("", Strict => True), "run_config: empty path");
      begin
         Run_Config_Or_Raise (Fx & "tls-polycallrc");
      exception
         when E : Polycall_Error => S := Status_Of (E);
      end;
      Expect (E_Unsupported, S, "Run_Config_Or_Raise: raises with the status");
      declare
         D : constant String := Describe (Root & "/ada-polycallrc");
      begin
         Check (D'Length > 0 and then D (D'First) = '{' and then Contains (D, "log_level"),
                "describe: JSON", D);
      end;
   end Test_Run_Config;

   procedure Test_Call is
      Ep     : constant String := Env ("POLYCALL_RPC_ENDPOINT");
      Status : Status_Code;
      Output : Unbounded_String;
   begin
      Call ("127.0.0.1:1", "debug", "echo", "{}", 1500, Status, Output);
      Expect (E_Transport, Status, "call: no runtime -> E_TRANSPORT");
      if Ep = "" then
         Skip ("call: success / unknown op / deadline / invalid input",
               "POLYCALL_RPC_ENDPOINT not set (run via tests/run-real.sh)");
         return;
      end if;
      declare
         Out1 : constant String := Call (Ep, "inventory", "get", "{""item_id"":""widget-a""}", 3000);
      begin
         Check (Out1 = "{""item_id"":""widget-a"",""quantity"":42,""in_stock"":true}",
                "call: inventory.get exact output", Out1);
      end;
      declare
         Out2 : constant String := Call (Ep, "debug", "echo", "{""n"":[1,2,3]}", 3000);
      begin
         Check (Out2 = "{""echo"":{""n"":[1,2,3]}}", "call: debug.echo exact output", Out2);
      end;
      Check (Call (Ep, "debug", "echo") = "{""echo"":null}", "call: empty input is sent as null");
      Call (Ep, "inventory", "teleport", "{}", 3000, Status, Output);
      Expect (E_Not_Found, Status, "call: unknown operation -> E_NOT_FOUND");
      Check (Contains (To_String (Output), "operation.unknown"), "call: unknown operation error object",
             To_String (Output));
      Call (Ep, "inventory", "get", "{""item_id"":""nope""}", 3000, Status, Output);
      Expect (E_Remote, Status, "call: unknown item -> E_REMOTE");
      Check (Contains (To_String (Output), "item.unknown"), "call: E_REMOTE error object", To_String (Output));
      Call (Ep, "debug", "sleep", "{""ms"":3000}", 200, Status, Output);
      Expect (E_Timeout, Status, "call: deadline -> E_TIMEOUT");
      Call (Ep, "debug", "echo", "{not json", 1000, Status, Output);
      Expect (E_Invalid_Argument, Status, "call: invalid input JSON -> E_INVALID_ARGUMENT");
      begin
         declare
            Ignored : constant String := Call (Ep, "inventory", "teleport", "{}", 3000);
         begin
            Check (False, "call: raising form raises", Ignored);
         end;
      exception
         when E : Polycall_Error =>
            Expect (E_Not_Found, Status_Of (E), "call: raising form carries the status");
      end;
   end Test_Call;

   procedure Exchange (From : Peer; From_Id : String; To : Peer; Payload : Bytes;
                       Mid, Label : String) is
   begin
      Send (From, Endpoint (To), Payload, Mid);
      declare
         M : constant Message := Receive (To, 5000);
      begin
         Check (To_String (M.Sender) = From_Id and then To_String (M.Id) = Mid
                and then M.Payload = Payload, Label,
                "sender=" & To_String (M.Sender) & " id=" & To_String (M.Id)
                & " len=" & Img (Integer (M.Length)));
      end;
   exception
      when E : Polycall_Error =>
         Check (False, Label, Ada.Exceptions.Exception_Message (E));
   end Exchange;

   procedure Test_Peers is
      A, B, S : Peer;
      Bin     : constant Bytes := (0, 1, 0, 255, 127, 0, 128);
      Utf8    : constant String := "h" & Character'Val (16#C3#) & Character'Val (16#A9#) & "llo "
        & Character'Val (16#E2#) & Character'Val (16#9C#) & Character'Val (16#93#);
      type Bytes_Access is access Bytes;
      procedure Free is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);
      Mib     : Bytes_Access := new Bytes (1 .. Max_Payload + 1);
      Status  : Status_Code;
   begin
      Open (A, "ada-a");
      Open (B, "ada-b");
      Check (Contains (Endpoint (A), "127.0.0.1:") and Endpoint (A) /= "127.0.0.1:0",
             "peer: ephemeral endpoint", Endpoint (A));
      Check (Node_Id (A) = "ada-a", "peer: node_id");
      Check (Contains (Health (A), """node_id"":""ada-a"""), "peer: health JSON", Health (A));
      for I in Mib'Range loop
         Mib (I) := Ada.Streams.Stream_Element ((Long_Long_Integer (I) * 31 + 7) mod 256);
      end loop;
      Exchange (A, "ada-a", B, (1 .. 0 => 0), "m-empty-ab", "peer a->b: empty payload");
      Exchange (B, "ada-b", A, (1 .. 0 => 0), "m-empty-ba", "peer b->a: empty payload");
      Exchange (A, "ada-a", B, To_Bytes (Utf8), "m-utf8-ab", "peer a->b: UTF-8");
      Exchange (B, "ada-b", A, To_Bytes (Utf8), "m-utf8-ba", "peer b->a: UTF-8");
      Exchange (A, "ada-a", B, Bin, "m-bin-ab", "peer a->b: binary with NUL");
      Exchange (B, "ada-b", A, Bin, "m-bin-ba", "peer b->a: binary with NUL");
      Exchange (A, "ada-a", B, Mib (1 .. Max_Payload), "m-mib-ab", "peer a->b: exactly 1 MiB");
      Exchange (B, "ada-b", A, Mib (1 .. Max_Payload), "m-mib-ba", "peer b->a: exactly 1 MiB");
      Status := OK;
      begin
         Send (A, Endpoint (B), Mib.all, "m-over");
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Too_Large, Status, "peer: 1 MiB + 1 -> E_TOO_LARGE");
      Status := OK;
      begin
         declare
            M : constant Message := Receive (B, 200);
         begin
            Check (False, "peer: oversize payload never delivered", To_String (M.Id));
         end;
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Timeout, Status, "peer: oversize payload never delivered");

      --  registry ownership
      Register (A, "ada-b", Endpoint (B));
      Check (Contains (List (A), """ada-b"":""" & Endpoint (B) & """"), "registry: register on a", List (A));
      Check (List (B) = "{}", "registry: b's registry is its own (empty)", List (B));
      Send (A, "ada-b", "by-id", "m-by-id");
      declare
         M : constant Message := Receive (B, 5000);
      begin
         Check (To_String (M.Payload) = "by-id" and To_String (M.Sender) = "ada-a",
                "registry: send by registered id");
      end;
      Check (List (B) = "{}", "registry: receiving does not register the sender", List (B));
      begin
         Ping (A, "ada-b");
         Ping (A, Endpoint (B));
         Check (True, "ping: registered id and host:port");
      exception
         when E : Polycall_Error =>
            Check (False, "ping: registered id and host:port", Ada.Exceptions.Exception_Message (E));
      end;
      Register (A, "impostor", Endpoint (B));
      Status := OK;
      begin
         Ping (A, "impostor");
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Protocol, Status, "ping: id answered by another node -> E_PROTOCOL");
      Unregister (A, "impostor");
      Status := OK;
      begin
         Unregister (A, "impostor");
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Not_Found, Status, "registry: unregister unknown -> E_NOT_FOUND");
      Status := OK;
      begin
         Register (A, "bad id!", Endpoint (B));
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Invalid_Argument, Status, "registry: invalid id -> E_INVALID_ARGUMENT");

      --  duplicate message id
      Send (A, Endpoint (B), "dup", "m-dup");
      Send (A, Endpoint (B), "dup", "m-dup");
      declare
         M : constant Message := Receive (B, 5000);
      begin
         Check (To_String (M.Id) = "m-dup", "duplicate: first copy delivered");
      end;
      Status := OK;
      begin
         declare
            M : constant Message := Receive (B, 300);
         begin
            Check (False, "duplicate: second copy dropped", To_String (M.Id));
         end;
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Timeout, Status, "duplicate: second copy dropped");

      --  generated id, receive timeout, too-small buffer
      Send (A, Endpoint (B), "gen");
      declare
         M : constant Message := Receive (B, 5000);
      begin
         Check (Length (M.Id) > 0 and To_String (M.Payload) = "gen", "send: empty message id is generated");
      end;
      declare
         T0 : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      begin
         Status := OK;
         begin
            declare
               M : constant Message := Receive (B, 150);
            begin
               Check (False, "recv: timeout -> E_TIMEOUT", "got " & To_String (M.Id));
            end;
         exception
            when E : Polycall_Error => Status := Status_Of (E);
         end;
         Expect (E_Timeout, Status, "recv: timeout -> E_TIMEOUT");
         Check (Ada.Calendar.Clock - T0 >= 0.1, "recv: waited for the timeout");
      end;
      Send (A, Endpoint (B), "0123456789", "m-small");
      declare
         M : constant Message := Receive (B, 1000, Initial_Capacity => 4);
      begin
         Check (To_String (M.Payload) = "0123456789" and To_String (M.Id) = "m-small",
                "recv: 4-byte buffer -> E_TOO_LARGE kept the message queued (regrown)");
      end;

      --  send-only node
      Open_Send_Only (S, "ada-sendonly");
      Check (Endpoint (S) = "", "send-only: empty endpoint");
      Send (S, Endpoint (B), "so", "m-so");
      declare
         M : constant Message := Receive (B, 5000);
      begin
         Check (To_String (M.Sender) = "ada-sendonly", "send-only: can send");
      end;
      Free (Mib);
   exception
      when E : Polycall_Error =>
         Free (Mib);
         Check (False, "peers: unexpected Polycall_Error", Ada.Exceptions.Exception_Message (E));
   end Test_Peers;

   procedure Test_Auth_Transport is
      Sec, Anon, Wrong, Member : Peer;
      Dead   : Unbounded_String;
      Status : Status_Code;
   begin
      Open (Sec, "ada-secured", "127.0.0.1:0", "qa-secret-1");
      Open_Send_Only (Anon, "ada-anon");
      Open_Send_Only (Wrong, "ada-wrong", "nope");
      Open_Send_Only (Member, "ada-member", "qa-secret-1");
      Status := OK;
      begin
         Send (Anon, Endpoint (Sec), "x", "m-a1");
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Auth, Status, "auth: no token -> E_AUTH");
      Status := OK;
      begin
         Send (Wrong, Endpoint (Sec), "x", "m-a2");
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Auth, Status, "auth: wrong token -> E_AUTH");
      Send (Member, Endpoint (Sec), "x", "m-a3");
      declare
         M : constant Message := Receive (Sec, 5000);
      begin
         Check (To_String (M.Sender) = "ada-member", "auth: right token delivers");
      end;
      declare
         P : Peer;
      begin
         Status := OK;
         begin
            Open (P, "ada-open", "0.0.0.0:0");
         exception
            when E : Polycall_Error => Status := Status_Of (E);
         end;
         Expect (E_Config, Status, "open: non-loopback without token -> E_CONFIG");
         Status := OK;
         begin
            Open (P, "bad id", "127.0.0.1:0");
         exception
            when E : Polycall_Error => Status := Status_Of (E);
         end;
         Expect (E_Invalid_Argument, Status, "open: invalid node id");
      end;
      declare
         Gone : Peer;
      begin
         Open (Gone, "ada-gone");
         Dead := To_Unbounded_String (Endpoint (Gone));
         Close (Gone);
      end;
      Status := OK;
      begin
         Send (Member, To_String (Dead), "x", "m-dead", 3000);
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Transport, Status, "send to a dead peer -> E_TRANSPORT");
   end Test_Auth_Transport;

   task type Blocked_Receiver (Node : access constant Peer) is
      entry Result (S : out Status_Code);
   end Blocked_Receiver;

   task body Blocked_Receiver is
      St : Status_Code := OK;
   begin
      begin
         declare
            M : constant Message := Receive (Node.all, Wait_Forever);
         begin
            St := (if Length (M.Id) > 0 then OK else E_Internal);
         end;
      exception
         when E : Polycall_Error => St := Status_Of (E);
      end;
      accept Result (S : out Status_Code) do
         S := St;
      end Result;
   end Blocked_Receiver;

   task type Sender_Task is
      entry Start (Index : Natural; Target : String);
      entry Done (Failures : out Natural);
   end Sender_Task;

   task body Sender_Task is
      Idx   : Natural := 0;
      Ep    : Unbounded_String;
      Fails : Natural := 0;
   begin
      accept Start (Index : Natural; Target : String) do
         Idx := Index;
         Ep := To_Unbounded_String (Target);
      end Start;
      declare
         Tx : Peer;
      begin
         Open_Send_Only (Tx, "ada-tx" & Img (Idx));
         for I in 0 .. 24 loop
            begin
               Send (Tx, To_String (Ep), "t" & Img (Idx) & "-" & Img (I),
                     "m-" & Img (Idx) & "-" & Img (I), 10000);
            exception
               when Polycall_Error => Fails := Fails + 1;
            end;
         end loop;
      exception
         when Polycall_Error => Fails := 25;
      end;
      accept Done (Failures : out Natural) do
         Failures := Fails;
      end Done;
   end Sender_Task;

   package String_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

   procedure Test_Tasks is
      R      : aliased Peer;
      Status : Status_Code;
   begin
      Open (R, "ada-blocked");
      declare
         T : Blocked_Receiver (R'Access);
      begin
         delay 0.3;
         Cancel (R);
         T.Result (Status);
      end;
      Expect (E_Cancelled, Status, "cancel wakes a blocked Receive -> E_CANCELLED");
      declare
         T : Blocked_Receiver (R'Access);
      begin
         delay 0.3;
         Close (R);
         T.Result (Status);
      end;
      Expect (E_Closed, Status, "close wakes a blocked Receive -> E_CLOSED");
      Status := OK;
      begin
         Close (R);
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Invalid_Handle, Status, "double close -> E_INVALID_HANDLE");
      Status := OK;
      begin
         Check (Endpoint (R) = "never", "endpoint after close");
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Invalid_Handle, Status, "endpoint after close -> E_INVALID_HANDLE");
      Status := OK;
      begin
         Send (R, "127.0.0.1:1", "x");
      exception
         when E : Polycall_Error => Status := Status_Of (E);
      end;
      Expect (E_Invalid_Handle, Status, "send after close -> E_INVALID_HANDLE");
      declare
         Never : Peer;   --  never opened: handle 0
      begin
         Status := OK;
         begin
            Ping (Never, "127.0.0.1:1", 100);
         exception
            when E : Polycall_Error => Status := Status_Of (E);
         end;
         Expect (E_Invalid_Handle, Status, "unopened Peer (handle 0) -> E_INVALID_HANDLE");
      end;

      declare
         Rx      : Peer;
         Senders : array (0 .. 3) of Sender_Task;
         Seen    : String_Sets.Set;
         Fails   : Natural := 0;
         F       : Natural;
      begin
         Open (Rx, "ada-rx");
         for I in Senders'Range loop
            Senders (I).Start (I, Endpoint (Rx));
         end loop;
         for I in 1 .. 100 loop
            declare
               M : constant Message := Receive (Rx, 10000);
            begin
               Seen.Include (To_String (M.Sender) & "/" & To_String (M.Id));
            end;
         end loop;
         for I in Senders'Range loop
            Senders (I).Done (F);
            Fails := Fails + F;
         end loop;
         Check (Natural (Seen.Length) = 100 and Fails = 0,
                "concurrent senders: 4 tasks x 25 messages, all delivered once",
                Img (Natural (Seen.Length)) & " unique, " & Img (Fails) & " failures");
      exception
         when E : Polycall_Error =>
            Check (False, "concurrent senders", Ada.Exceptions.Exception_Message (E));
      end;
   end Test_Tasks;

   procedure Test_Interop is
      Cli      : constant String := Env ("POLYCALL_CLI");
      Cli_Peer : constant String := Env ("POLYCALL_CLI_PEER");
      Payload  : constant Bytes :=
        To_Bytes ("ada" & Character'Val (0) & "bin" & Character'Val (1) & Character'Val (255) & " "
                  & Character'Val (16#C3#) & Character'Val (16#A9#) & " end");
      Node     : Peer;
      Rc       : Integer;
   begin
      if Cli = "" or Cli_Peer = "" then
         Skip ("interop: polycall CLI peer -> Ada", "POLYCALL_CLI/POLYCALL_CLI_PEER not set");
         Skip ("interop: Ada -> polycall CLI peer", "POLYCALL_CLI/POLYCALL_CLI_PEER not set");
         return;
      end if;
      Open (Node, "ada-node", "127.0.0.1:0", Env ("POLYCALL_DEV_TOKEN"));
      declare
         F : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, "ada_cli_payload.bin");
         Ada.Streams.Stream_IO.Write (F, Payload);
         Ada.Streams.Stream_IO.Close (F);
      end;
      Rc := Run ("""" & Cli & """ peer send --to " & Endpoint (Node)
                 & " --payload-file ada_cli_payload.bin --from cli-node --id cli-to-ada-1"
                 & " -t 5000 > ada_cli_send.log 2>&1");
      begin
         declare
            M : constant Message := Receive (Node, 5000);
         begin
            Check (Rc = 0 and then To_String (M.Sender) = "cli-node"
                   and then To_String (M.Id) = "cli-to-ada-1" and then M.Payload = Payload,
                   "interop: polycall CLI peer send -> Ada Peer (bytes, sender, id)");
         end;
      exception
         when E : Polycall_Error =>
            Check (False, "interop: polycall CLI peer send -> Ada Peer (bytes, sender, id)",
                   "rc=" & Img (Rc) & " " & Ada.Exceptions.Exception_Message (E) & " "
                   & Slurp ("ada_cli_send.log"));
      end;
      Register (Node, "cli-node", Cli_Peer);
      begin
         Ping (Node, "cli-node");
         Check (True, "interop: ping the CLI node by id");
         Send (Node, "cli-node", Payload, "ada-to-cli-1");
         Rc := Run ("""" & Cli & """ --format json peer recv --to " & Cli_Peer
                    & " -t 5000 > ada_cli_recv.json 2>&1");
         declare
            Got : constant String := Slurp ("ada_cli_recv.json");
         begin
            Check (Rc = 0 and then Contains (Got, """from"":""ada-node""")
                   and then Contains (Got, """id"":""ada-to-cli-1""")
                   and then Contains (Got, """payload_b64"":""" & Base64 (Payload) & """"),
                   "interop: Ada Peer -> polycall peer serve, read by polycall peer recv", Got);
         end;
      exception
         when E : Polycall_Error =>
            Check (False, "interop: Ada Peer -> polycall CLI peer", Ada.Exceptions.Exception_Message (E));
      end;
      if Run ("rm -f ada_cli_payload.bin ada_cli_send.log ada_cli_recv.json") /= 0 then
         Put_Line ("note: could not remove interop temp files");
      end if;
   end Test_Interop;

begin
   Put_Line ("ada-polycall real-core tests: libpolycall " & Version
             & ", ABI " & Img (ABI_Version));
   Test_Version;
   Test_Run_Config;
   Test_Call;
   Test_Peers;
   Test_Auth_Transport;
   Test_Tasks;
   Test_Interop;
   Put_Line ("SUMMARY pass=" & Img (Passed) & " fail=" & Img (Failed)
             & " skip=" & Img (Skipped));
   if Failed > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Ada_Polycall_Test;

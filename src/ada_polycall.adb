with Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body Ada_Polycall is

   use Ada.Streams;
   use Ada.Strings.Unbounded;
   use Interfaces;
   use Interfaces.C;

   subtype Peer_Handle is Interfaces.Integer_32;

   --  Binding ABI v1 imports (exact signatures of <polycall.h>) -----------

   function C_ABI_Version return int
     with Import, Convention => C, External_Name => "polycall_ffi_abi_version";
   function C_Version (Buf : out char_array; Len : int) return int
     with Import, Convention => C, External_Name => "polycall_ffi_version";
   function C_Strerror (Status : int) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "polycall_strerror";
   function C_Last_Error (Buf : out char_array; Cap : size_t) return int
     with Import, Convention => C, External_Name => "polycall_last_error";
   function C_Run_Config (Path : char_array; Run : int) return int
     with Import, Convention => C, External_Name => "polycall_ffi_run_config";
   function C_Describe
     (Path : char_array; Buf : System.Address; Len : int) return int
     with Import, Convention => C, External_Name => "polycall_ffi_describe";
   function C_Call
     (Endpoint, Service, Operation : char_array;
      Input      : System.Address;
      Timeout_Ms : Unsigned_32;
      Output     : System.Address;
      Output_Cap : size_t;
      Output_Len : out size_t) return int
     with Import, Convention => C, External_Name => "polycall_call";
   function C_Peer_Open
     (Node_Id : char_array;
      Bind    : System.Address;
      Token   : System.Address;
      Handle  : out Peer_Handle) return int
     with Import, Convention => C, External_Name => "polycall_peer_open";
   function C_Peer_Close (H : Peer_Handle) return int
     with Import, Convention => C, External_Name => "polycall_peer_close";
   function C_Peer_Endpoint
     (H : Peer_Handle; Buf : out char_array; Cap : size_t) return int
     with Import, Convention => C, External_Name => "polycall_peer_endpoint";
   function C_Peer_Node_Id
     (H : Peer_Handle; Buf : out char_array; Cap : size_t) return int
     with Import, Convention => C, External_Name => "polycall_peer_node_id";
   function C_Peer_Register
     (H : Peer_Handle; Peer_Id, Endpoint : char_array) return int
     with Import, Convention => C, External_Name => "polycall_peer_register";
   function C_Peer_Unregister (H : Peer_Handle; Peer_Id : char_array) return int
     with Import, Convention => C,
          External_Name => "polycall_peer_unregister";
   function C_Peer_List
     (H : Peer_Handle; Buf : System.Address; Cap : size_t;
      Out_Len : out size_t) return int
     with Import, Convention => C, External_Name => "polycall_peer_list";
   function C_Peer_Ping
     (H : Peer_Handle; Target : char_array; Timeout_Ms : Unsigned_32)
      return int
     with Import, Convention => C, External_Name => "polycall_peer_ping";
   function C_Peer_Send
     (H          : Peer_Handle;
      Target     : char_array;
      Payload    : System.Address;
      Len        : size_t;
      Message_Id : System.Address;
      Timeout_Ms : Unsigned_32) return int
     with Import, Convention => C, External_Name => "polycall_peer_send";
   function C_Peer_Recv
     (H              : Peer_Handle;
      Timeout_Ms     : Unsigned_32;
      Sender         : out char_array;
      Sender_Cap     : size_t;
      Message_Id     : out char_array;
      Message_Id_Cap : size_t;
      Payload        : System.Address;
      Payload_Cap    : size_t;
      Payload_Len    : out size_t) return int
     with Import, Convention => C, External_Name => "polycall_peer_recv";
   function C_Peer_Cancel (H : Peer_Handle) return int
     with Import, Convention => C, External_Name => "polycall_peer_cancel";
   function C_Peer_Health
     (H : Peer_Handle; Buf : System.Address; Cap : size_t;
      Out_Len : out size_t) return int
     with Import, Convention => C, External_Name => "polycall_peer_health";

   type Char_Array_Access is access char_array;
   procedure Free is new Ada.Unchecked_Deallocation
     (char_array, Char_Array_Access);
   type Bytes_Access is access Bytes;
   procedure Free is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);

   Status_Prefix : constant String := "status=";

   function Image (V : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (V), Ada.Strings.Left));

   --  Raise Polycall_Error for Status. Reads polycall_last_error first: it
   --  is per thread and must not be overwritten by another ABI call.
   procedure Raise_Status (Status : int; Context : String) is
      Detail : constant String := Last_Error;
      Name   : constant String := Error_Name (Integer (Status));
   begin
      raise Polycall_Error with
        Status_Prefix & Image (Integer (Status)) & " " & Name
        & (if Detail /= "" then " (" & Detail & ")" else "")
        & " [" & Context & "]";
   end Raise_Status;

   procedure Check (Status : int; Context : String) is
   begin
      if Status /= 0 then
         Raise_Status (Status, Context);
      end if;
   end Check;

   procedure Require_ABI is
   begin
      if Integer (C_ABI_Version) /= Expected_ABI_Version then
         Check_ABI;
      end if;
   end Require_ABI;

   --  Library ------------------------------------------------------------

   function ABI_Version return Integer is (Integer (C_ABI_Version));

   function Version return String is
      Buf : char_array (0 .. 63) := (others => nul);
      N   : constant int := C_Version (Buf, Buf'Length);
   begin
      if N < 0 then
         Raise_Status (N, "Version");
      end if;
      return To_Ada (Buf);
   end Version;

   function Error_Name (Status : Status_Code) return String is
     (Interfaces.C.Strings.Value (C_Strerror (int (Status))));

   function Last_Error return String is
      Buf : char_array (0 .. 2047) := (others => nul);
      N   : constant int := C_Last_Error (Buf, Buf'Length);
   begin
      if N < 0 then
         return "";
      end if;
      return To_Ada (Buf);
   end Last_Error;

   procedure Check_ABI is
      Got : constant Integer := ABI_Version;
   begin
      if Got /= Expected_ABI_Version then
         raise Polycall_Error with
           Status_Prefix & Image (E_Unsupported) & " "
           & Error_Name (E_Unsupported) & " (libpolycall reports binding ABI "
           & Image (Got) & ", ada-polycall requires ABI "
           & Image (Expected_ABI_Version) & ") [Check_ABI]";
      end if;
   end Check_ABI;

   function Status_Of
     (Occurrence : Ada.Exceptions.Exception_Occurrence) return Status_Code
   is
      M     : constant String := Ada.Exceptions.Exception_Message (Occurrence);
      First : constant Integer := M'First + Status_Prefix'Length;
      Last  : Integer := First;
   begin
      if M'Length <= Status_Prefix'Length
        or else M (M'First .. First - 1) /= Status_Prefix
      then
         return E_Internal;
      end if;
      while Last <= M'Last and then M (Last) /= ' ' loop
         Last := Last + 1;
      end loop;
      return Status_Code'Value (M (First .. Last - 1));
   exception
      when Constraint_Error =>
         return E_Internal;
   end Status_Of;

   --  Configuration --------------------------------------------------------

   function Run_Config
     (Config_Path : String := Default_Config) return Integer is
     (Run_Config (Config_Path, Strict => True));

   function Run_Config
     (Config_Path : String; Strict : Boolean) return Integer is
   begin
      if Integer (C_ABI_Version) /= Expected_ABI_Version then
         return E_Unsupported;
      end if;
      return Integer
        (C_Run_Config (To_C (Config_Path), (if Strict then 1 else 0)));
   end Run_Config;

   procedure Run_Config_Or_Raise
     (Config_Path : String := Default_Config; Strict : Boolean := True)
   is
      Status : int;
   begin
      Require_ABI;
      Status := C_Run_Config (To_C (Config_Path), (if Strict then 1 else 0));
      Check (Status, "Run_Config '" & Config_Path & "'");
   end Run_Config_Or_Raise;

   function Describe (Config_Path : String) return String is
      Cap : size_t := 16 * 1024;
   begin
      Require_ABI;
      loop
         declare
            Buf : Char_Array_Access := new char_array (0 .. Cap - 1);
            N   : constant int :=
              C_Describe (To_C (Config_Path), Buf (0)'Address, int (Cap));
         begin
            if N < 0 then
               Free (Buf);
               Raise_Status (N, "Describe '" & Config_Path & "'");
            elsif size_t (N) < Cap then
               declare
                  Result : constant String := To_Ada (Buf.all);
               begin
                  Free (Buf);
                  return Result;
               end;
            end if;
            Free (Buf);
            Cap := size_t (N) + 1;
         end;
      end loop;
   end Describe;

   --  RPC ------------------------------------------------------------------

   procedure Call
     (Endpoint, Service, Operation : String;
      Input_JSON : String;
      Timeout_Ms : Positive;
      Status     : out Status_Code;
      Output     : out Unbounded_String)
   is
      Buf   : Char_Array_Access;
      Input : constant char_array := To_C (Input_JSON);
      Len   : size_t := 0;
      St    : int;
   begin
      if Integer (C_ABI_Version) /= Expected_ABI_Version then
         Status := E_Unsupported;   --  non-raising form: report, do not raise
         Output := Null_Unbounded_String;
         return;
      end if;
      Buf := new char_array (0 .. size_t (Max_Call_Output));
      Buf (0) := nul;
      Buf (Buf'Last) := nul;
      St := C_Call
        (To_C (Endpoint), To_C (Service), To_C (Operation),
         (if Input_JSON = "" then System.Null_Address
          else Input (Input'First)'Address),
         Unsigned_32 (Timeout_Ms), Buf (0)'Address, Buf'Length, Len);
      Status := Integer (St);
      if St = 0 and then Len < Buf'Length then
         Output := To_Unbounded_String
           (To_Ada (Buf (0 .. Len), Trim_Nul => True));
      else
         Output := To_Unbounded_String (To_Ada (Buf.all));
      end if;
      Free (Buf);
   end Call;

   function Call
     (Endpoint, Service, Operation : String;
      Input_JSON : String := "";
      Timeout_Ms : Positive := 5000) return String
   is
      Status : Status_Code;
      Output : Unbounded_String;
   begin
      Require_ABI;   --  raises Polycall_Error naming the ABI it found
      Call (Endpoint, Service, Operation, Input_JSON, Timeout_Ms,
            Status, Output);
      if Status /= OK then
         Raise_Status
           (int (Status),
            "Call " & Service & "." & Operation & " @ " & Endpoint
            & (if Length (Output) > 0 then " -> " & To_String (Output)
               else ""));
      end if;
      return To_String (Output);
   end Call;

   --  Peer nodes -------------------------------------------------------------

   function To_Bytes (S : String) return Bytes is
      Result : Bytes (1 .. S'Length);
   begin
      for I in S'Range loop
         Result (Stream_Element_Offset (I - S'First + 1)) :=
           Stream_Element (Character'Pos (S (I)));
      end loop;
      return Result;
   end To_Bytes;

   function To_String (B : Bytes) return String is
      Result : String (1 .. B'Length);
   begin
      for I in B'Range loop
         Result (Integer (I - B'First + 1)) := Character'Val (B (I));
      end loop;
      return Result;
   end To_String;

   procedure Do_Open
     (Node : in out Peer; Node_Id : String; Bind : String;
      Listen : Boolean; Auth_Token : String)
   is
      C_Bind  : constant char_array := To_C (Bind);
      C_Token : constant char_array := To_C (Auth_Token);
      H       : Peer_Handle := 0;
      Status  : int;
   begin
      Require_ABI;
      Status := C_Peer_Open
        (To_C (Node_Id),
         (if Listen then C_Bind (C_Bind'First)'Address
          else System.Null_Address),
         (if Auth_Token = "" then System.Null_Address
          else C_Token (C_Token'First)'Address),
         H);
      Check (Status, "Open '" & Node_Id & "'");
      Node.H := H;
      Node.Live := True;
   end Do_Open;

   procedure Open
     (Node          : in out Peer;
      Node_Id       : String;
      Bind_Endpoint : String := "127.0.0.1:0";
      Auth_Token    : String := "") is
   begin
      Do_Open (Node, Node_Id, Bind_Endpoint, True, Auth_Token);
   end Open;

   procedure Open_Send_Only
     (Node : in out Peer; Node_Id : String; Auth_Token : String := "") is
   begin
      Do_Open (Node, Node_Id, "", False, Auth_Token);
   end Open_Send_Only;

   procedure Close (Node : in out Peer) is
      Status : constant int := C_Peer_Close (Node.H);
   begin
      Node.Live := False;
      Check (Status, "Close");
   end Close;

   overriding procedure Finalize (Node : in out Peer) is
      Ignored : int;
   begin
      if Node.Live then
         Ignored := C_Peer_Close (Node.H);
         Node.Live := False;
      end if;
   end Finalize;

   function Is_Open (Node : Peer) return Boolean is (Node.Live);
   function Handle (Node : Peer) return Interfaces.Integer_32 is (Node.H);

   function Endpoint (Node : Peer) return String is
      Buf : char_array (0 .. 255) := (others => nul);
   begin
      Check (C_Peer_Endpoint (Node.H, Buf, Buf'Length), "Endpoint");
      return To_Ada (Buf);
   end Endpoint;

   function Node_Id (Node : Peer) return String is
      Buf : char_array (0 .. 63) := (others => nul);
   begin
      Check (C_Peer_Node_Id (Node.H, Buf, Buf'Length), "Node_Id");
      return To_Ada (Buf);
   end Node_Id;

   procedure Register (Node : Peer; Peer_Id : String; Endpoint : String) is
   begin
      Check (C_Peer_Register (Node.H, To_C (Peer_Id), To_C (Endpoint)),
             "Register '" & Peer_Id & "'");
   end Register;

   procedure Unregister (Node : Peer; Peer_Id : String) is
   begin
      Check (C_Peer_Unregister (Node.H, To_C (Peer_Id)),
             "Unregister '" & Peer_Id & "'");
   end Unregister;

   type JSON_Getter is access function
     (H : Peer_Handle; Buf : System.Address; Cap : size_t;
      Out_Len : out size_t) return int with Convention => C;

   function Read_JSON
     (Node : Peer; Get : JSON_Getter; Context : String) return String
   is
      Cap : size_t := 4096;
   begin
      loop
         declare
            Buf    : Char_Array_Access := new char_array (0 .. Cap - 1);
            Needed : size_t := 0;
            Status : constant int := Get (Node.H, Buf (0)'Address, Cap, Needed);
         begin
            if Integer (Status) = E_Too_Large and then Needed >= Cap then
               Free (Buf);
               Cap := Needed + 1;
            elsif Status /= 0 then
               Free (Buf);
               Raise_Status (Status, Context);
            else
               declare
                  Result : constant String := To_Ada (Buf.all);
               begin
                  Free (Buf);
                  return Result;
               end;
            end if;
         end;
      end loop;
   end Read_JSON;

   function List (Node : Peer) return String is
     (Read_JSON (Node, C_Peer_List'Access, "List"));

   function Health (Node : Peer) return String is
     (Read_JSON (Node, C_Peer_Health'Access, "Health"));

   procedure Ping
     (Node : Peer; Target : String; Timeout_Ms : Natural := 3000) is
   begin
      Check (C_Peer_Ping (Node.H, To_C (Target), Unsigned_32 (Timeout_Ms)),
             "Ping '" & Target & "'");
   end Ping;

   procedure Send
     (Node       : Peer;
      Target     : String;
      Payload    : Bytes;
      Message_Id : String := "";
      Timeout_Ms : Natural := 5000)
   is
      Empty : aliased constant Bytes (1 .. 1) := (others => 0);
      C_Id  : constant char_array := To_C (Message_Id);
   begin
      Check
        (C_Peer_Send
           (Node.H, To_C (Target),
            (if Payload'Length = 0 then Empty (1)'Address
             else Payload (Payload'First)'Address),
            size_t (Payload'Length),
            (if Message_Id = "" then System.Null_Address
             else C_Id (C_Id'First)'Address),
            Unsigned_32 (Timeout_Ms)),
         "Send to '" & Target & "'");
   end Send;

   procedure Send
     (Node       : Peer;
      Target     : String;
      Payload    : String;
      Message_Id : String := "";
      Timeout_Ms : Natural := 5000) is
   begin
      Send (Node, Target, To_Bytes (Payload), Message_Id, Timeout_Ms);
   end Send;

   function Receive
     (Node             : Peer;
      Timeout_Ms       : Interfaces.Unsigned_32 := Wait_Forever;
      Initial_Capacity : Ada.Streams.Stream_Element_Offset := 65_536)
      return Message
   is
      Cap    : Stream_Element_Offset :=
        Stream_Element_Offset'Max (Initial_Capacity, 1);
      Sender : char_array (0 .. 63);
      Id     : char_array (0 .. 63);
      Len    : size_t := 0;
      Status : int;
      Buf    : Bytes_Access;
   begin
      loop
         Buf := new Bytes (1 .. Cap);
         Sender (0) := nul;
         Id (0) := nul;
         Status := C_Peer_Recv
           (Node.H, Timeout_Ms, Sender, Sender'Length, Id, Id'Length,
            Buf (1)'Address, size_t (Cap), Len);
         exit when Integer (Status) /= E_Too_Large
           or else Stream_Element_Offset (Len) <= Cap;
         --  the message stays queued: retry with room for it
         Cap := Stream_Element_Offset (Len);
         Free (Buf);
      end loop;
      if Status /= 0 then
         Free (Buf);
         Raise_Status (Status, "Receive");
      end if;
      return M : Message (Stream_Element_Offset (Len)) do
         M.Sender := To_Unbounded_String (To_Ada (Sender));
         M.Id := To_Unbounded_String (To_Ada (Id));
         M.Payload := Buf (1 .. Stream_Element_Offset (Len));
         Free (Buf);
      end return;
   end Receive;

   procedure Cancel (Node : Peer) is
   begin
      Check (C_Peer_Cancel (Node.H), "Cancel");
   end Cancel;

end Ada_Polycall;

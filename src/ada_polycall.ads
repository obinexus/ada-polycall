--  Ada binding for the Polycall binding ABI v1 (<polycall.h>, polycall >=
--  1.1.0; docs/BINDING_ABI.md in https://github.com/obinexus/polycall).
--
--  The C functions are imported directly (Convention C, Interfaces.C); the
--  binding owns no parser, socket or protocol code. Failures raise
--  Polycall_Error whose message starts with "status=<code> <NAME>" followed
--  by the core's detail (polycall_last_error); Status_Of recovers the code.

with Ada.Exceptions;
with Ada.Finalization;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Interfaces;

package Ada_Polycall is

   Polycall_Error : exception;

   subtype Status_Code is Integer;

   OK                 : constant Status_Code := 0;
   E_Invalid_Argument : constant Status_Code := -1;
   E_No_Memory        : constant Status_Code := -2;
   E_Invalid_Handle   : constant Status_Code := -3;
   E_Timeout          : constant Status_Code := -4;
   E_Transport        : constant Status_Code := -5;
   E_Protocol         : constant Status_Code := -6;
   E_Not_Found        : constant Status_Code := -7;
   E_Auth             : constant Status_Code := -8;
   E_Remote           : constant Status_Code := -9;
   E_Too_Large        : constant Status_Code := -10;
   E_Busy             : constant Status_Code := -11;
   E_Cancelled        : constant Status_Code := -12;
   E_Config           : constant Status_Code := -13;
   E_Address_In_Use   : constant Status_Code := -14;
   E_Unsupported      : constant Status_Code := -15;
   E_Permission       : constant Status_Code := -16;
   E_Closed           : constant Status_Code := -17;
   E_Internal         : constant Status_Code := -18;

   Expected_ABI_Version : constant := 1;
   Max_Payload          : constant := 2 ** 20;   --  POLYCALL_PEER_MAX_PAYLOAD
   Max_Call_Output      : constant := 2 ** 20;   --  POLYCALL_CALL_MAX_OUTPUT
   Wait_Forever         : constant Interfaces.Unsigned_32 :=
     Interfaces.Unsigned_32'Last;
   Default_Config       : constant String := "ada-polycallrc";

   --  Library ------------------------------------------------------------

   function ABI_Version return Integer;            --  polycall_ffi_abi_version
   function Version return String;                 --  "1.1.0"
   function Error_Name (Status : Status_Code) return String;  --  strerror
   function Last_Error return String;              --  this task's detail
   procedure Check_ABI;  --  raises Polycall_Error unless ABI_Version = 1

   --  Status code carried by a Polycall_Error occurrence (E_Internal when
   --  the occurrence did not come from this binding).
   function Status_Of
     (Occurrence : Ada.Exceptions.Exception_Occurrence) return Status_Code;

   --  Configuration --------------------------------------------------------

   --  Historical entry point: polycall_ffi_run_config (Config_Path, 1);
   --  the status is returned unchanged.
   function Run_Config
     (Config_Path : String := Default_Config) return Integer;
   --  Strict => False validates only (unknown keys are warnings).
   function Run_Config
     (Config_Path : String; Strict : Boolean) return Integer;
   --  Raise Polycall_Error when libpolycall returns a nonzero status.
   procedure Run_Config_Or_Raise
     (Config_Path : String := Default_Config; Strict : Boolean := True);
   function Describe (Config_Path : String) return String;

   --  RPC ------------------------------------------------------------------

   --  One polycall_rpc v1 round trip, never retried. Input_JSON "" = null.
   --  Output is the operation's output JSON, or the remote error object
   --  {"code":..,"message":..} when Status is E_Remote / E_Not_Found /
   --  E_Timeout / E_Busy.
   procedure Call
     (Endpoint, Service, Operation : String;
      Input_JSON : String;
      Timeout_Ms : Positive;
      Status     : out Status_Code;
      Output     : out Ada.Strings.Unbounded.Unbounded_String);
   --  As above, raising Polycall_Error on failure.
   function Call
     (Endpoint, Service, Operation : String;
      Input_JSON : String := "";
      Timeout_Ms : Positive := 5000) return String;

   --  Peer nodes -------------------------------------------------------------

   subtype Bytes is Ada.Streams.Stream_Element_Array;

   type Message (Length : Ada.Streams.Stream_Element_Offset) is record
      Sender  : Ada.Strings.Unbounded.Unbounded_String;
      Id      : Ada.Strings.Unbounded.Unbounded_String;
      Payload : Bytes (1 .. Length);
   end record;

   function To_Bytes (S : String) return Bytes;
   function To_String (B : Bytes) return String;

   --  One peer node. Limited and controlled: finalization closes it. Close
   --  asks the core every time, so a second Close raises E_Invalid_Handle,
   --  as does any operation on a closed node.
   type Peer is new Ada.Finalization.Limited_Controlled with private;

   procedure Open
     (Node          : in out Peer;
      Node_Id       : String;
      Bind_Endpoint : String := "127.0.0.1:0";
      Auth_Token    : String := "");
   procedure Open_Send_Only
     (Node : in out Peer; Node_Id : String; Auth_Token : String := "");
   procedure Close (Node : in out Peer);
   function Is_Open (Node : Peer) return Boolean;
   function Handle (Node : Peer) return Interfaces.Integer_32;

   function Endpoint (Node : Peer) return String;   --  "" when send-only
   function Node_Id (Node : Peer) return String;
   procedure Register (Node : Peer; Peer_Id : String; Endpoint : String);
   procedure Unregister (Node : Peer; Peer_Id : String);
   function List (Node : Peer) return String;      --  {"id":"host:port"}
   procedure Ping
     (Node : Peer; Target : String; Timeout_Ms : Natural := 3000);
   --  Exactly one delivery attempt; Message_Id "" = generated by the core.
   procedure Send
     (Node       : Peer;
      Target     : String;
      Payload    : Bytes;
      Message_Id : String := "";
      Timeout_Ms : Natural := 5000);
   procedure Send
     (Node       : Peer;
      Target     : String;
      Payload    : String;
      Message_Id : String := "";
      Timeout_Ms : Natural := 5000);
   --  Oldest message; raises Polycall_Error (E_Timeout) when none arrived.
   --  A too-small buffer is grown and the call retried (the core keeps the
   --  message queued on E_Too_Large). Initial_Capacity >= 1.
   function Receive
     (Node             : Peer;
      Timeout_Ms       : Interfaces.Unsigned_32 := Wait_Forever;
      Initial_Capacity : Ada.Streams.Stream_Element_Offset := 65_536)
      return Message;
   procedure Cancel (Node : Peer);                 --  wake blocked Receive
   function Health (Node : Peer) return String;    --  JSON

private

   type Peer is new Ada.Finalization.Limited_Controlled with record
      H    : Interfaces.Integer_32 := 0;
      Live : Boolean := False;
   end record;

   overriding procedure Finalize (Node : in out Peer);

end Ada_Polycall;

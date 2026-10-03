--  Loader check for tests/loader-errors.sh: what an Ada program sees from
--  the library it was started with. Prints one line per step:
--
--    loader-check: abi=<n>
--    loader-check: check_abi=<status> <message>
--    loader-check: run_config=<status>
--    loader-check: call=<status>   (127.0.0.1:1: E_TRANSPORT with the real core)
--    loader-check: peer_open=<status> <message>
--
--  Run from the repository root (it validates ./ada-polycallrc).

with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada_Polycall;

procedure Loader_Check is
   use Ada.Text_IO;
   use Ada_Polycall;

   function Img (V : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (V), Ada.Strings.Left));
begin
   Put_Line ("loader-check: abi=" & Img (ABI_Version));
   begin
      Check_ABI;
      Put_Line ("loader-check: check_abi=0 OK");
   exception
      when E : Polycall_Error =>
         Put_Line ("loader-check: check_abi=" & Img (Status_Of (E)) & " "
                   & Ada.Exceptions.Exception_Message (E));
   end;
   Put_Line ("loader-check: run_config=" & Img (Run_Config ("ada-polycallrc")));
   declare
      Status : Status_Code;
      Output : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Call ("127.0.0.1:1", "debug", "echo", "{}", 1000, Status, Output);
      Put_Line ("loader-check: call=" & Img (Status));
   end;
   declare
      P : Peer;
   begin
      Open (P, "loader-check");
      Close (P);
      Put_Line ("loader-check: peer_open=0 OK");
   exception
      when E : Polycall_Error =>
         Put_Line ("loader-check: peer_open=" & Img (Status_Of (E)) & " "
                   & Ada.Exceptions.Exception_Message (E));
   end;
end Loader_Check;

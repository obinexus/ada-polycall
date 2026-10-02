with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada_Polycall;

procedure Basic is
   use Ada.Text_IO;
   Config : constant String :=
     (if Ada.Command_Line.Argument_Count > 0
      then Ada.Command_Line.Argument (1) else "ada-polycallrc");
begin
   Ada_Polycall.Check_ABI;
   Put_Line ("ada-polycall: libpolycall " & Ada_Polycall.Version);
   Ada_Polycall.Run_Config_Or_Raise (Config);
   Put_Line ("ada-polycall: '" & Config & "' is valid for this build");

   declare
      Alpha, Beta : Ada_Polycall.Peer;
   begin
      Ada_Polycall.Open (Alpha, "alpha");
      Ada_Polycall.Open (Beta, "beta");
      Ada_Polycall.Register (Alpha, "beta", Ada_Polycall.Endpoint (Beta));
      Ada_Polycall.Send (Alpha, "beta", "hello from Ada", "example-1");
      declare
         M : constant Ada_Polycall.Message :=
           Ada_Polycall.Receive (Beta, 5000);
      begin
         Put_Line ("beta received '" & Ada_Polycall.To_String (M.Payload)
                   & "' from " & Ada.Strings.Unbounded.To_String (M.Sender));
      end;
   end;
exception
   when E : Ada_Polycall.Polycall_Error =>
      Put_Line (Standard_Error, "ada-polycall: "
                & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Basic;

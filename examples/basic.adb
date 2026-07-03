with Ada.Text_IO;
with Ada_Polycall;

procedure Basic is
begin
   Ada_Polycall.Run_Config_Or_Raise ("ada-polycallrc");
   Ada.Text_IO.Put_Line
     ("ada-polycall: configuration started successfully");
end Basic;

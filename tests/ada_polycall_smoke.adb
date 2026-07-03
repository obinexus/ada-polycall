with Ada.Text_IO;
with Ada_Polycall;

procedure Ada_Polycall_Smoke is
   Status : constant Integer :=
     Ada_Polycall.Run_Config ("../ada-polycallrc");
begin
   if Status /= 0 then
      raise Program_Error with
        "expected status 0, got" & Integer'Image (Status);
   end if;

   Ada.Text_IO.Put_Line ("ada-polycall Ada smoke test: PASS");
end Ada_Polycall_Smoke;

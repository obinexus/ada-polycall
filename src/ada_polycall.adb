with Interfaces.C;
with Interfaces.C.Strings;

package body Ada_Polycall is
   function Ada_Polycall_Run_Config
     (Config_Path : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.int
   with Import,
        Convention    => C,
        External_Name => "ada_polycall_run_config";

   function Run_Config
     (Config_Path : String) return Integer
   is
      C_Path : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Config_Path);
      Status : Interfaces.C.int;
   begin
      Status := Ada_Polycall_Run_Config (C_Path);
      Interfaces.C.Strings.Free (C_Path);
      return Integer (Status);
   end Run_Config;

   procedure Run_Config_Or_Raise
     (Config_Path : String)
   is
      Status : constant Integer := Run_Config (Config_Path);
   begin
      if Status /= 0 then
         raise Polycall_Error with
           "libpolycall failed for '" & Config_Path &
           "' (status=" & Integer'Image (Status) & ")";
      end if;
   end Run_Config_Or_Raise;
end Ada_Polycall;

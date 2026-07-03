package Ada_Polycall is
   Polycall_Error : exception;

   --  Run libpolycall with the supplied read-only Ada configuration.
   --  The status returned by the C FFI is propagated unchanged.
   function Run_Config
     (Config_Path : String := "ada-polycallrc") return Integer;

   --  Raise Polycall_Error when libpolycall returns a nonzero status.
   procedure Run_Config_Or_Raise
     (Config_Path : String := "ada-polycallrc");
end Ada_Polycall;

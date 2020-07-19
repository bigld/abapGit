INTERFACE zif_abapgit_gui_log_handler
  PUBLIC .

  METHODS handle_log
        FOR EVENT log_created OF zif_abapgit_log
    IMPORTING
        !ir_log
        !sender.
ENDINTERFACE.

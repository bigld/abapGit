CLASS zcl_abapgit_object_docv DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_objects_super
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_abapgit_object.

    METHODS constructor
      IMPORTING
        !is_item        TYPE zif_abapgit_definitions=>ty_item
        !iv_language    TYPE spras
        !io_files       TYPE REF TO zcl_abapgit_objects_files OPTIONAL
        !io_i18n_params TYPE REF TO zcl_abapgit_i18n_params OPTIONAL
      RAISING
        zcx_abapgit_exception.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_data,
        doctitle TYPE dsyst-doktitle,
        head     TYPE thead,
        lines    TYPE tline_tab,
      END OF ty_data.
    TYPES:
      ty_data_tt TYPE STANDARD TABLE OF ty_data WITH DEFAULT KEY.

    CONSTANTS c_typ TYPE dokhl-typ VALUE 'E' ##NO_TEXT.
    CONSTANTS c_first_version TYPE dokhl-dokversion VALUE '0001' ##NO_TEXT.
    CONSTANTS c_state_active TYPE dokhl-dokstate VALUE 'A' ##NO_TEXT.
    CONSTANTS c_name TYPE string VALUE 'DOC' ##NO_TEXT.
    CONSTANTS c_name_i18n TYPE string VALUE 'I18N_DOC' ##NO_TEXT.

    DATA mv_id TYPE dokhl-id.
    DATA mv_doc_object TYPE dokhl-object.

    METHODS get_version
      IMPORTING
        !iv_language      TYPE spras
      RETURNING
        VALUE(rv_version) TYPE dokhl-dokversion.
    METHODS read
      IMPORTING
        !iv_language   TYPE spras
      RETURNING
        VALUE(rs_data) TYPE ty_data.
    METHODS write
      IMPORTING
        !is_data         TYPE ty_data
        !iv_no_main_lang TYPE abap_bool.
    METHODS clear_fields
      CHANGING
        !cs_data TYPE ty_data.
ENDCLASS.



CLASS zcl_abapgit_object_docv IMPLEMENTATION.


  METHOD constructor.

    DATA: lv_prefix    TYPE namespace,
          lv_bare_name TYPE progname.

    super->constructor(
      is_item        = is_item
      iv_language    = iv_language
      io_files       = io_files
      io_i18n_params = io_i18n_params ).

    IF ms_item-obj_name(2) <> 'DT' AND ms_item-obj_name NP '/*/DT*'. " IN, MO, UO, UP
      mv_id         = ms_item-obj_name(2).
      mv_doc_object = ms_item-obj_name+2.
    ELSE. " DT
      CALL FUNCTION 'RS_NAME_SPLIT_NAMESPACE'
        EXPORTING
          name_with_namespace    = ms_item-obj_name
        IMPORTING
          namespace              = lv_prefix
          name_without_namespace = lv_bare_name
        EXCEPTIONS
          delimiter_error        = 1
          OTHERS                 = 2.
      IF sy-subrc <> 0.
        zcx_abapgit_exception=>raise( |Error determining namespace for { ms_item-obj_type } { ms_item-obj_name }| ).
      ENDIF.

      mv_id         = lv_bare_name(2).
      mv_doc_object = |{ lv_prefix }{ lv_bare_name+2 }|.
    ENDIF.

  ENDMETHOD.


  METHOD clear_fields.

    CLEAR: cs_data-head-tdfuser,
           cs_data-head-tdfreles,
           cs_data-head-tdfdate,
           cs_data-head-tdftime,
           cs_data-head-tdluser,
           cs_data-head-tdlreles,
           cs_data-head-tdldate,
           cs_data-head-tdltime.

  ENDMETHOD.


  METHOD get_version.

    " DOKIL holds the current version of the document per language
    SELECT SINGLE version FROM dokil INTO rv_version
      WHERE id     = mv_id
        AND object = mv_doc_object
        AND langu  = iv_language
        AND typ    = c_typ.

  ENDMETHOD.


  METHOD read.

    DATA lv_version TYPE dokhl-dokversion.


    lv_version = get_version( iv_language ).
    IF lv_version IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'DOCU_READ'
      EXPORTING
        id       = mv_id
        langu    = iv_language
        object   = mv_doc_object
        typ      = c_typ
        version  = lv_version
      IMPORTING
        doktitle = rs_data-doctitle
        head     = rs_data-head
      TABLES
        line     = rs_data-lines.

  ENDMETHOD.


  METHOD write.

    DATA: lv_version TYPE dokhl-dokversion,
          ls_current TYPE ty_data,
          lt_lines   TYPE tline_tab.


    lv_version = get_version( is_data-head-tdspras ).

    IF lv_version IS INITIAL.
      lv_version = c_first_version.
    ELSE.
      " Only create a new version if the text has changed
      ls_current = read( is_data-head-tdspras ).
      IF ls_current-lines = is_data-lines.
        RETURN.
      ENDIF.
      lv_version = lv_version + 1.
    ENDIF.

    lt_lines = is_data-lines.

    CALL FUNCTION 'DOCU_UPDATE'
      EXPORTING
        head          = is_data-head
        state         = c_state_active
        typ           = c_typ
        version       = lv_version
        no_masterlang = iv_no_main_lang
      TABLES
        line          = lt_lines.

  ENDMETHOD.


  METHOD zif_abapgit_object~changed_by.
    rv_user = read( mv_language )-head-tdluser.
    IF rv_user IS INITIAL.
      rv_user = c_user_unknown.
    ENDIF.
  ENDMETHOD.


  METHOD zif_abapgit_object~delete.

    DATA: lt_languages TYPE zif_abapgit_definitions=>ty_sap_langu_tab,
          lv_language  LIKE LINE OF lt_languages.


    SELECT langu FROM dokil INTO TABLE lt_languages
      WHERE id     = mv_id
        AND object = mv_doc_object
        AND typ    = c_typ
      ORDER BY langu.                                     "#EC CI_GENBUFF

    LOOP AT lt_languages INTO lv_language.

      CALL FUNCTION 'DOCU_DEL'
        EXPORTING
          id       = mv_id
          langu    = lv_language
          object   = mv_doc_object
          typ      = c_typ
        EXCEPTIONS
          ret_code = 1
          OTHERS   = 2.
      IF sy-subrc <> 0.
        zcx_abapgit_exception=>raise_t100( ).
      ENDIF.

    ENDLOOP.

    corr_insert( iv_package ).

  ENDMETHOD.


  METHOD zif_abapgit_object~deserialize.

    DATA: ls_data TYPE ty_data,
          lt_i18n TYPE ty_data_tt.

    FIELD-SYMBOLS: <ls_i18n> LIKE LINE OF lt_i18n.


    io_xml->read( EXPORTING iv_name = c_name
                  CHANGING cg_data = ls_data ).

    write( is_data         = ls_data
           iv_no_main_lang = abap_false ).

    io_xml->read( EXPORTING iv_name = c_name_i18n
                  CHANGING cg_data = lt_i18n ).

    LOOP AT lt_i18n ASSIGNING <ls_i18n>.
      write( is_data         = <ls_i18n>
             iv_no_main_lang = abap_true ).
    ENDLOOP.

    tadir_insert( iv_package ).

    corr_insert( iv_package ).

  ENDMETHOD.


  METHOD zif_abapgit_object~exists.

    SELECT SINGLE id FROM dokil INTO mv_id
       WHERE id     = mv_id
         AND object = mv_doc_object.    "#EC CI_GENBUFF "#EC CI_NOORDER

    rv_bool = boolc( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD zif_abapgit_object~get_comparator.
    RETURN.
  ENDMETHOD.


  METHOD zif_abapgit_object~get_deserialize_order.
    RETURN.
  ENDMETHOD.


  METHOD zif_abapgit_object~get_deserialize_steps.
    APPEND zif_abapgit_object=>gc_step_id-abap TO rt_steps.
  ENDMETHOD.


  METHOD zif_abapgit_object~get_metadata.
    rs_metadata = get_metadata( ).
  ENDMETHOD.


  METHOD zif_abapgit_object~is_active.
    rv_active = is_active( ).
  ENDMETHOD.


  METHOD zif_abapgit_object~is_locked.
    rv_is_locked = abap_false.
  ENDMETHOD.


  METHOD zif_abapgit_object~jump.
  ENDMETHOD.


  METHOD zif_abapgit_object~map_filename_to_object.
    RETURN.
  ENDMETHOD.


  METHOD zif_abapgit_object~map_object_to_filename.
    RETURN.
  ENDMETHOD.


  METHOD zif_abapgit_object~serialize.

    DATA: ls_data      TYPE ty_data,
          lt_i18n      TYPE ty_data_tt,
          lt_languages TYPE zif_abapgit_definitions=>ty_sap_langu_tab,
          lv_language  LIKE LINE OF lt_languages.


    ls_data = read( mv_language ).
    clear_fields( CHANGING cs_data = ls_data ).

    io_xml->add( iv_name = c_name
                 ig_data = ls_data ).

    IF mo_i18n_params->ms_params-main_language_only = abap_true.
      RETURN.
    ENDIF.

    SELECT langu FROM dokil INTO TABLE lt_languages
      WHERE id       = mv_id
        AND object   = mv_doc_object
        AND typ      = c_typ
        AND langu    <> mv_language
        AND txtlines > 0
      ORDER BY langu.                                     "#EC CI_GENBUFF

    mo_i18n_params->trim_saplang_list( CHANGING ct_sap_langs = lt_languages ).

    LOOP AT lt_languages INTO lv_language.
      ls_data = read( lv_language ).
      clear_fields( CHANGING cs_data = ls_data ).
      APPEND ls_data TO lt_i18n.
    ENDLOOP.

    IF lt_i18n IS NOT INITIAL.
      io_xml->add( iv_name = c_name_i18n
                   ig_data = lt_i18n ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.

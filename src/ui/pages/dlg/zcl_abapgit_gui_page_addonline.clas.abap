CLASS zcl_abapgit_gui_page_addonline DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_gui_component
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    INTERFACES zif_abapgit_gui_event_handler.
    INTERFACES zif_abapgit_gui_renderable.

    CLASS-METHODS create
      RETURNING
        VALUE(ri_page) TYPE REF TO zif_abapgit_gui_renderable
      RAISING
        zcx_abapgit_exception.

    METHODS constructor
      RAISING
        zcx_abapgit_exception.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF c_id,
        url                TYPE string VALUE 'url',
        package            TYPE string VALUE 'package',
        branch_name        TYPE string VALUE 'branch_name',
        display_name       TYPE string VALUE 'display_name',
        labels             TYPE string VALUE 'labels',
        folder_logic       TYPE string VALUE 'folder_logic',
        ignore_subpackages TYPE string VALUE 'ignore_subpackages',
        main_lang_only     TYPE string VALUE 'main_lang_only',
        abap_lang_vers     TYPE string VALUE 'abap_lang_vers',
      END OF c_id.

    CONSTANTS:
      BEGIN OF c_event,
        choose_package  TYPE string VALUE 'choose-package',
        create_package  TYPE string VALUE 'create-package',
        choose_branch   TYPE string VALUE 'choose-branch',
        choose_labels   TYPE string VALUE 'choose-labels',
        add_online_repo TYPE string VALUE 'add-repo-online',
      END OF c_event.

    DATA mo_form TYPE REF TO zcl_abapgit_html_form .
    DATA mo_form_data TYPE REF TO zcl_abapgit_string_map .
    DATA mo_form_util TYPE REF TO zcl_abapgit_html_form_utils.
    DATA mo_validation_log TYPE REF TO zcl_abapgit_string_map .

    METHODS validate_form
      IMPORTING
        io_form_data             TYPE REF TO zcl_abapgit_string_map
      RETURNING
        VALUE(ro_validation_log) TYPE REF TO zcl_abapgit_string_map
      RAISING
        zcx_abapgit_exception.

    METHODS get_form_schema
      RETURNING
        VALUE(ro_form) TYPE REF TO zcl_abapgit_html_form.

    METHODS choose_labels
      RAISING
        zcx_abapgit_exception.

ENDCLASS.



CLASS zcl_abapgit_gui_page_addonline IMPLEMENTATION.


  METHOD choose_labels.

    DATA:
      lv_old_labels TYPE string,
      lv_new_labels TYPE string.

    lv_old_labels = mo_form_data->get( c_id-labels ).

    lv_new_labels = zcl_abapgit_ui_factory=>get_popups( )->popup_to_select_labels( lv_old_labels ).

    mo_form_data->set(
      iv_key = c_id-labels
      iv_val = lv_new_labels ).

  ENDMETHOD.


  METHOD constructor.
    super->constructor( ).
    CREATE OBJECT mo_validation_log.
    CREATE OBJECT mo_form_data.
    mo_form = get_form_schema( ).
    mo_form_util = zcl_abapgit_html_form_utils=>create( mo_form ).
  ENDMETHOD.


  METHOD create.

    DATA lo_component TYPE REF TO zcl_abapgit_gui_page_addonline.

    CREATE OBJECT lo_component.

    ri_page = zcl_abapgit_gui_page_hoc=>create(
      iv_page_title      = 'New Online Repository'
      ii_child_component = lo_component ).

  ENDMETHOD.


  METHOD get_form_schema.

    ro_form = zcl_abapgit_html_form=>create(
                iv_form_id   = 'add-repo-online-form'
                iv_help_page = 'https://docs.abapgit.org/guide-online-install.html' ).

    ro_form->text(
      iv_name        = c_id-url
      iv_required    = abap_true
      iv_condense    = abap_true
      iv_label       = 'Git Repository URL'
      iv_hint        = 'HTTPS address of the repository'
      iv_placeholder = 'https://github.com/...git'
    )->text(
      iv_name        = c_id-package
      iv_side_action = c_event-choose_package
      iv_required    = abap_true
      iv_upper_case  = abap_true
      iv_label       = 'Package'
      iv_hint        = 'SAP package for repository (should be a dedicated one)'
      iv_placeholder = 'Z... / $...'
      iv_max         = 30
    )->text(
      iv_name        = c_id-branch_name
      iv_side_action = c_event-choose_branch
      iv_label       = 'Branch'
      iv_hint        = 'Switch to a specific branch (default: autodetect)'
      iv_placeholder = 'Autodetect default branch'
    )->radio(
      iv_name        = c_id-folder_logic
      iv_default_value = zif_abapgit_dot_abapgit=>c_folder_logic-prefix
      iv_label       = 'Folder Logic'
      iv_hint        = 'Define how package folders are named in repository'
    )->option(
      iv_label       = 'Prefix'
      iv_value       = zif_abapgit_dot_abapgit=>c_folder_logic-prefix
    )->option(
      iv_label       = 'Full'
      iv_value       = zif_abapgit_dot_abapgit=>c_folder_logic-full
    )->option(
      iv_label       = 'Mixed'
      iv_value       = zif_abapgit_dot_abapgit=>c_folder_logic-mixed
    )->text(
      iv_name        = c_id-display_name
      iv_label       = 'Display Name'
      iv_hint        = 'Name to show instead of original repository name (optional)'
    )->text(
      iv_name        = c_id-labels
      iv_side_action = c_event-choose_labels
      iv_label       = |Labels (comma-separated, allowed chars: "{ zcl_abapgit_repo_labels=>c_allowed_chars }")|
      iv_hint        = 'Comma-separated labels for grouping and repo organization (optional)'
    )->checkbox(
      iv_name        = c_id-ignore_subpackages
      iv_label       = 'Ignore Subpackages'
      iv_hint        = 'Synchronize root package only'
    )->checkbox(
      iv_name        = c_id-main_lang_only
      iv_label       = 'Serialize Main Language Only'
      iv_hint        = 'Ignore translations, serialize just main language' ).

    IF zcl_abapgit_feature=>is_enabled( zcl_abapgit_abap_language_vers=>c_feature_flag ) = abap_true.
      ro_form->radio(
        iv_name        = c_id-abap_lang_vers
        iv_default_value = ''
        iv_label       = 'ABAP Language Version'
        iv_hint        = 'Define the ABAP language version for objects in the repository'
      )->option(
        iv_label       = 'Any'
        iv_value       = ''
      )->option(
        iv_label       = 'Ignore'
        iv_value       = zif_abapgit_dot_abapgit=>c_abap_language_version-ignore
      )->option(
        iv_label       = 'Standard'
        iv_value       = zif_abapgit_dot_abapgit=>c_abap_language_version-standard
      )->option(
        iv_label       = 'For Key Users'
        iv_value       = zif_abapgit_dot_abapgit=>c_abap_language_version-key_user
      )->option(
        iv_label       = 'For Cloud Development'
        iv_value       = zif_abapgit_dot_abapgit=>c_abap_language_version-cloud_development ).
    ENDIF.

    ro_form->command(
      iv_label       = 'Create Online Repo'
      iv_cmd_type    = zif_abapgit_html_form=>c_cmd_type-input_main
      iv_action      = c_event-add_online_repo
    )->command(
      iv_label       = 'Create Package'
      iv_action      = c_event-create_package
    )->command(
      iv_label       = 'Back'
      iv_action      = zif_abapgit_definitions=>c_action-go_back ).

  ENDMETHOD.


  METHOD validate_form.

    DATA:
      lv_url TYPE string,
      lo_url TYPE REF TO zcl_abapgit_git_url,
      lx_err TYPE REF TO zcx_abapgit_exception.

    ro_validation_log = mo_form_util->validate( io_form_data ).

    lv_url = io_form_data->get( c_id-url ).
    IF lv_url IS NOT INITIAL.
      TRY.
          zcl_abapgit_repo_srv=>get_instance( )->validate_url( lv_url ).

          " Provider-specific URL check
          CREATE OBJECT lo_url.
          lo_url->validate_url( lv_url ).
        CATCH zcx_abapgit_exception INTO lx_err.
          ro_validation_log->set(
            iv_key = c_id-url
            iv_val = lx_err->get_text( ) ).
      ENDTRY.

      zcl_abapgit_http=>check_connection( lv_url ).
    ENDIF.

    IF io_form_data->get( c_id-package ) IS NOT INITIAL.
      TRY.
          zcl_abapgit_repo_srv=>get_instance( )->validate_package(
            iv_package    = |{ io_form_data->get( c_id-package ) }|
            iv_ign_subpkg = |{ io_form_data->get( c_id-ignore_subpackages ) }| ).
        CATCH zcx_abapgit_exception INTO lx_err.
          ro_validation_log->set(
            iv_key = c_id-package
            iv_val = lx_err->get_text( ) ).
      ENDTRY.
    ENDIF.

    IF io_form_data->get( c_id-folder_logic ) <> zif_abapgit_dot_abapgit=>c_folder_logic-prefix
        AND io_form_data->get( c_id-folder_logic ) <> zif_abapgit_dot_abapgit=>c_folder_logic-full
        AND io_form_data->get( c_id-folder_logic ) <> zif_abapgit_dot_abapgit=>c_folder_logic-mixed.
      ro_validation_log->set(
        iv_key = c_id-folder_logic
        iv_val = |Invalid folder logic { io_form_data->get( c_id-folder_logic ) }| ).
    ENDIF.

    TRY.
        zcl_abapgit_repo_labels=>validate( io_form_data->get( c_id-labels ) ).
      CATCH zcx_abapgit_exception INTO lx_err.
        ro_validation_log->set(
          iv_key = c_id-labels
          iv_val = lx_err->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD zif_abapgit_gui_event_handler~on_event.

    DATA ls_repo_params TYPE zif_abapgit_services_repo=>ty_repo_params.
    DATA li_new_repo    TYPE REF TO zif_abapgit_repo.
    DATA lv_package     TYPE devclass.

    mo_form_data = mo_form_util->normalize( ii_event->form_data( ) ).

    CASE ii_event->mv_action.
      WHEN c_event-create_package.
        lv_package = mo_form_data->get( c_id-package ).
        rs_handled-page  = zcl_abapgit_gui_page_cpackage=>create( lv_package ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page.

      WHEN c_event-choose_package.

        mo_form_data->set(
          iv_key = c_id-package
          iv_val = zcl_abapgit_ui_factory=>get_popups( )->popup_search_help( 'TDEVC-DEVCLASS' ) ).
        IF mo_form_data->get( c_id-package ) IS NOT INITIAL.
          mo_validation_log = validate_form( mo_form_data ).
          rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
        ELSE.
          rs_handled-state = zcl_abapgit_gui=>c_event_state-no_more_act.
        ENDIF.

      WHEN c_event-choose_branch.

        mo_validation_log = validate_form( mo_form_data ).
        IF mo_validation_log->has( c_id-url ) = abap_true.
          mo_validation_log->set(
            iv_key = c_id-branch_name
            iv_val = 'Check URL issues' ).
          rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render. " Display errors
          RETURN.
        ENDIF.
        mo_form_data->set(
          iv_key = c_id-branch_name
          iv_val = zcl_abapgit_ui_factory=>get_popups( )->branch_list_popup( mo_form_data->get( c_id-url ) )-name ).

        IF mo_form_data->get( c_id-branch_name ) IS INITIAL.
          rs_handled-state = zcl_abapgit_gui=>c_event_state-no_more_act.
        ELSE.
          mo_form_data->set(
            iv_key = c_id-branch_name
            iv_val = replace( " strip technical
              val = mo_form_data->get( c_id-branch_name )
              sub = zif_abapgit_git_definitions=>c_git_branch-heads_prefix
              with = '' ) ).
          rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
        ENDIF.

      WHEN c_event-choose_labels.

        choose_labels( ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.

      WHEN c_event-add_online_repo.

        mo_validation_log = validate_form( mo_form_data ).

        IF mo_validation_log->is_empty( ) = abap_true.
          mo_form_data->to_abap( CHANGING cs_container = ls_repo_params ).
          li_new_repo = zcl_abapgit_services_repo=>new_online( ls_repo_params ).
          rs_handled-page  = zcl_abapgit_gui_page_repo_view=>create( li_new_repo->get_key( ) ).
          rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page_replacing.
        ELSE.
          rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render. " Display errors
        ENDIF.

    ENDCASE.

  ENDMETHOD.


  METHOD zif_abapgit_gui_renderable~render.

    register_handlers( ).

    CREATE OBJECT ri_html TYPE zcl_abapgit_html.

    ri_html->add( '<div class="form-container">' ).
    ri_html->add( mo_form->render(
      io_values         = mo_form_data
      io_validation_log = mo_validation_log ) ).
    ri_html->add( '</div>' ).
  ENDMETHOD.
ENDCLASS.

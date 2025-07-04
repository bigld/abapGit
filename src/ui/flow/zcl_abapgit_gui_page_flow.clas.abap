CLASS zcl_abapgit_gui_page_flow DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_gui_component
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    INTERFACES zif_abapgit_gui_event_handler .
    INTERFACES zif_abapgit_gui_renderable .
    INTERFACES zif_abapgit_gui_menu_provider .

    CLASS-METHODS create
      RETURNING
        VALUE(ri_page) TYPE REF TO zif_abapgit_gui_renderable
      RAISING
        zcx_abapgit_exception .
    METHODS constructor
      RAISING
        zcx_abapgit_exception .
  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF c_action,
        refresh             TYPE string VALUE 'refresh',
        consolidate         TYPE string VALUE 'consolicate',
        pull                TYPE string VALUE 'pull',
        stage               TYPE string VALUE 'stage',
        only_my_transports  TYPE string VALUE 'only_my_transports',
        hide_full_matches   TYPE string VALUE 'hide_full_matches',
        hide_matching_files TYPE string VALUE 'hide_matching_files',
      END OF c_action .
    DATA mt_features TYPE zif_abapgit_flow_logic=>ty_features .

    DATA: BEGIN OF ms_user_settings,
            only_my_transports  TYPE abap_bool,
            hide_full_matches   TYPE abap_bool,
            hide_matching_files TYPE abap_bool,
          END OF ms_user_settings.

    METHODS refresh
      RAISING
        zcx_abapgit_exception .
    METHODS set_branch
      IMPORTING
        !iv_branch TYPE string
        !iv_key    TYPE zif_abapgit_persistence=>ty_value
      RAISING
        zcx_abapgit_exception .

    METHODS render_table
      IMPORTING
        !is_feature    TYPE zif_abapgit_flow_logic=>ty_feature
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html .

    METHODS render_toolbar
      IMPORTING
        !iv_index      TYPE i
        !is_feature    TYPE zif_abapgit_flow_logic=>ty_feature
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html
      RAISING
        zcx_abapgit_exception .

    METHODS call_diff
      IMPORTING
        !ii_event         TYPE REF TO zif_abapgit_gui_event
      RETURNING
        VALUE(rs_handled) TYPE zif_abapgit_gui_event_handler=>ty_handling_result
      RAISING
        zcx_abapgit_exception.

    METHODS call_stage
      IMPORTING
        !ii_event         TYPE REF TO zif_abapgit_gui_event
      RETURNING
        VALUE(rs_handled) TYPE zif_abapgit_gui_event_handler=>ty_handling_result
      RAISING
        zcx_abapgit_exception.

    METHODS call_pull
      IMPORTING
        !ii_event         TYPE REF TO zif_abapgit_gui_event
      RETURNING
        VALUE(rs_handled) TYPE zif_abapgit_gui_event_handler=>ty_handling_result
      RAISING
        zcx_abapgit_exception.

    METHODS call_consolidate
      RETURNING
        VALUE(rs_handled) TYPE zif_abapgit_gui_event_handler=>ty_handling_result
      RAISING
        zcx_abapgit_exception.
ENDCLASS.



CLASS ZCL_ABAPGIT_GUI_PAGE_FLOW IMPLEMENTATION.


  METHOD constructor.
    super->constructor( ).

  ENDMETHOD.


  METHOD create.

    DATA lo_component TYPE REF TO zcl_abapgit_gui_page_flow.

    CREATE OBJECT lo_component.

    ri_page = zcl_abapgit_gui_page_hoc=>create(
      iv_page_title         = 'Flow'
      ii_page_menu_provider = lo_component
      ii_child_component    = lo_component ).

  ENDMETHOD.


  METHOD refresh.

    DATA ls_feature LIKE LINE OF mt_features.
    DATA li_repo  TYPE REF TO zif_abapgit_repo.


    LOOP AT mt_features INTO ls_feature.
      li_repo = zcl_abapgit_repo_srv=>get_instance( )->get( ls_feature-repo-key ).
      li_repo->refresh( ).
    ENDLOOP.

    CLEAR mt_features.

  ENDMETHOD.


  METHOD render_table.

    DATA ls_path_name LIKE LINE OF is_feature-changed_files.
    DATA lv_status    TYPE string.
    DATA lv_branch    TYPE string.
    DATA lv_param     TYPE string.


    CREATE OBJECT ri_html TYPE zcl_abapgit_html.

    ri_html->add( |<table>| ).
    ri_html->add( |<tr><td><u>Filename</u></td><td><u>Remote</u></td><td><u>Local</u></td><td></td></tr>| ).

    lv_branch = is_feature-branch-display_name.
    IF lv_branch IS INITIAL.
      lv_branch = 'main'.
    ENDIF.

    LOOP AT is_feature-changed_files INTO ls_path_name.
      IF ls_path_name-remote_sha1 = ls_path_name-local_sha1.
        IF ms_user_settings-hide_matching_files = abap_true.
          CONTINUE.
        ENDIF.
        lv_status = 'Match'.
      ELSE.
        ASSERT is_feature-repo-key IS NOT INITIAL.
        lv_param = zcl_abapgit_html_action_utils=>file_encode(
          iv_key   = is_feature-repo-key
          ig_file  = ls_path_name
          iv_extra = lv_branch ).
        lv_status = ri_html->a(
          iv_txt = 'Diff'
          iv_act = |{ zif_abapgit_definitions=>c_action-go_file_diff }?{
            lv_param }&remote_sha1={ ls_path_name-remote_sha1 }| ).
      ENDIF.

      ri_html->add( |<tr><td><tt>{ ls_path_name-path }{ ls_path_name-filename }</tt></td><td>{
        ls_path_name-remote_sha1(7) }</td><td>{
        ls_path_name-local_sha1(7) }</td><td>{ lv_status }</td></tr>| ).
    ENDLOOP.
    ri_html->add( |</table>| ).

  ENDMETHOD.


  METHOD render_toolbar.

    DATA lo_toolbar TYPE REF TO zcl_abapgit_html_toolbar.
    DATA lv_extra   TYPE string.
    DATA li_repo    TYPE REF TO zif_abapgit_repo.
    DATA lv_opt     TYPE c LENGTH 1.


    CREATE OBJECT ri_html TYPE zcl_abapgit_html.
    CREATE OBJECT lo_toolbar EXPORTING iv_id = 'toolbar-flow'.

    li_repo ?= zcl_abapgit_repo_srv=>get_instance( )->get( is_feature-repo-key ).
    IF li_repo->get_local_settings( )-write_protected = abap_true.
      lv_opt = zif_abapgit_html=>c_html_opt-crossout.
    ELSE.
      lv_opt = zif_abapgit_html=>c_html_opt-strong.
    ENDIF.

    IF is_feature-full_match = abap_false AND is_feature-branch-display_name IS NOT INITIAL.
      lv_extra = |?index={ iv_index }&key={ is_feature-repo-key }&branch={ is_feature-branch-display_name }|.
      lo_toolbar->add( iv_txt = 'Pull'
                       iv_act = |{ c_action-pull }{ lv_extra }|
                       iv_opt = lv_opt ).
      lo_toolbar->add( iv_txt = 'Stage'
                       iv_act = |{ c_action-stage }{ lv_extra }|
                       iv_opt = zif_abapgit_html=>c_html_opt-strong ).
    ENDIF.

    zcl_abapgit_flow_exit=>get_instance( )->toolbar_extras(
      io_toolbar = lo_toolbar
      iv_index   = iv_index
      is_feature = is_feature ).

    ri_html->add( lo_toolbar->render( ) ).

  ENDMETHOD.


  METHOD set_branch.

    DATA lv_branch TYPE string.
    DATA li_repo_online TYPE REF TO zif_abapgit_repo_online.

    IF iv_branch IS NOT INITIAL.
      lv_branch = 'refs/heads/' && iv_branch.
      li_repo_online ?= zcl_abapgit_repo_srv=>get_instance( )->get( iv_key ).
      IF li_repo_online->get_selected_branch( ) <> lv_branch.
        li_repo_online->select_branch( lv_branch ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD call_diff.

    DATA lv_key         TYPE zif_abapgit_persistence=>ty_value.
    DATA lv_branch      TYPE string.
    DATA lv_remote_sha1 TYPE zif_abapgit_git_definitions=>ty_sha1.
    DATA ls_file        TYPE zif_abapgit_git_definitions=>ty_file.
    DATA ls_object      TYPE zif_abapgit_definitions=>ty_item.
    DATA li_repo_online TYPE REF TO zif_abapgit_repo_online.
    DATA lv_blob        TYPE xstring.


    lv_key = ii_event->query( )->get( 'KEY' ).
    lv_branch = ii_event->query( )->get( 'EXTRA' ).
    lv_remote_sha1 = ii_event->query( )->get( 'REMOTE_SHA1' ).

    ls_file-path       = ii_event->query( )->get( 'PATH' ).
    ls_file-filename   = ii_event->query( )->get( 'FILENAME' ). " unescape ?
    ls_object-obj_type = ii_event->query( )->get( 'OBJ_TYPE' ).
    ls_object-obj_name = ii_event->query( )->get( 'OBJ_NAME' ). " unescape ?

    li_repo_online ?= zcl_abapgit_repo_srv=>get_instance( )->get( lv_key ).
    lv_blob = zcl_abapgit_git_factory=>get_v2_porcelain( )->fetch_blob(
      iv_url = li_repo_online->get_url( )
      iv_sha1 = lv_remote_sha1 ).

* todo

    set_branch(
      iv_branch = lv_branch
      iv_key    = lv_key ).

    rs_handled-page = zcl_abapgit_gui_page_diff=>create(
      iv_key    = lv_key
      is_file   = ls_file
      is_object = ls_object ).

    rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page_w_bookmark.

  ENDMETHOD.

  METHOD call_stage.

    DATA lv_key          TYPE zif_abapgit_persistence=>ty_value.
    DATA lv_branch       TYPE string.
    DATA lo_filter       TYPE REF TO lcl_filter.
    DATA lt_filter       TYPE zif_abapgit_definitions=>ty_tadir_tt.
    DATA lv_index        TYPE i.
    DATA li_repo_online  TYPE REF TO zif_abapgit_repo_online.
    DATA ls_feature      LIKE LINE OF mt_features.

    FIELD-SYMBOLS <ls_object> LIKE LINE OF ls_feature-changed_objects.
    FIELD-SYMBOLS <ls_filter> LIKE LINE OF lt_filter.

    lv_key = ii_event->query( )->get( 'KEY' ).
    lv_index = ii_event->query( )->get( 'INDEX' ).
    lv_branch = ii_event->query( )->get( 'BRANCH' ).
    li_repo_online ?= zcl_abapgit_repo_srv=>get_instance( )->get( lv_key ).

    READ TABLE mt_features INTO ls_feature INDEX lv_index.
    ASSERT sy-subrc = 0.

    LOOP AT ls_feature-changed_objects ASSIGNING <ls_object>.
      APPEND INITIAL LINE TO lt_filter ASSIGNING <ls_filter>.
      <ls_filter>-object = <ls_object>-obj_type.
      <ls_filter>-obj_name = <ls_object>-obj_name.
    ENDLOOP.
    CREATE OBJECT lo_filter EXPORTING it_filter = lt_filter.

    set_branch(
      iv_branch = lv_branch
      iv_key    = lv_key ).

    rs_handled-page = zcl_abapgit_gui_page_stage=>create(
      ii_force_refresh = abap_false
      ii_repo_online   = li_repo_online
      ii_obj_filter    = lo_filter ).

    rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page_w_bookmark.

    refresh( ).

  ENDMETHOD.

  METHOD call_pull.

    DATA lv_key          TYPE zif_abapgit_persistence=>ty_value.
    DATA lv_branch       TYPE string.
    DATA lo_filter       TYPE REF TO lcl_filter.
    DATA lt_filter       TYPE zif_abapgit_definitions=>ty_tadir_tt.
    DATA lv_index        TYPE i.
    DATA li_repo_online  TYPE REF TO zif_abapgit_repo_online.
    DATA ls_feature      LIKE LINE OF mt_features.

    FIELD-SYMBOLS <ls_object> LIKE LINE OF ls_feature-changed_objects.
    FIELD-SYMBOLS <ls_filter> LIKE LINE OF lt_filter.

    lv_key = ii_event->query( )->get( 'KEY' ).
    lv_index = ii_event->query( )->get( 'INDEX' ).
    lv_branch = ii_event->query( )->get( 'BRANCH' ).
    li_repo_online ?= zcl_abapgit_repo_srv=>get_instance( )->get( lv_key ).

    READ TABLE mt_features INTO ls_feature INDEX lv_index.
    ASSERT sy-subrc = 0.

    LOOP AT ls_feature-changed_objects ASSIGNING <ls_object>.
      APPEND INITIAL LINE TO lt_filter ASSIGNING <ls_filter>.
      <ls_filter>-object = <ls_object>-obj_type.
      <ls_filter>-obj_name = <ls_object>-obj_name.
    ENDLOOP.
    CREATE OBJECT lo_filter EXPORTING it_filter = lt_filter.

    set_branch(
          iv_branch = lv_branch
          iv_key    = lv_key ).

    rs_handled-page = zcl_abapgit_gui_page_pull=>create(
          ii_repo       = li_repo_online
          iv_trkorr     = ls_feature-transport-trkorr
          ii_obj_filter = lo_filter ).

    rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page.

    refresh( ).

  ENDMETHOD.

  METHOD call_consolidate.

    DATA lt_repos        TYPE zcl_abapgit_flow_logic=>ty_repos_tt.
    DATA li_repo         LIKE LINE OF lt_repos.

    lt_repos = zcl_abapgit_flow_logic=>list_repos( abap_false ).
    IF lines( lt_repos ) <> 1.
      MESSAGE 'Todo, repository selection popup' TYPE 'S'.
    ELSE.
      READ TABLE lt_repos INTO li_repo INDEX 1.
      ASSERT sy-subrc = 0.
      rs_handled-page  = zcl_abapgit_gui_page_flowcons=>create( li_repo ).
      rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page.
    ENDIF.

  ENDMETHOD.

  METHOD zif_abapgit_gui_event_handler~on_event.

    DATA ls_event_result TYPE zif_abapgit_flow_exit=>ty_event_result.


    CASE ii_event->mv_action.
      WHEN c_action-only_my_transports.
        ms_user_settings-only_my_transports = boolc( ms_user_settings-only_my_transports <> abap_true ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN c_action-hide_full_matches.
        ms_user_settings-hide_full_matches = boolc( ms_user_settings-hide_full_matches <> abap_true ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN c_action-hide_matching_files.
        ms_user_settings-hide_matching_files = boolc( ms_user_settings-hide_matching_files <> abap_true ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN c_action-refresh.
        refresh( ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN c_action-consolidate.
        rs_handled = call_consolidate( ).
      WHEN zif_abapgit_definitions=>c_action-go_file_diff.
        rs_handled = call_diff( ii_event ).
      WHEN c_action-stage.
        rs_handled = call_stage( ii_event ).
      WHEN c_action-pull.
        rs_handled = call_pull( ii_event ).
      WHEN OTHERS.
        ls_event_result = zcl_abapgit_flow_exit=>get_instance( )->on_event(
         ii_event    = ii_event
         it_features = mt_features ).

        rs_handled = ls_event_result-handled.

        IF ls_event_result-refresh = abap_true.
          refresh( ).
        ENDIF.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_abapgit_gui_menu_provider~get_menu.

    ro_toolbar = zcl_abapgit_html_toolbar=>create( 'toolbar-flow' ).

    ro_toolbar->add(
      iv_txt = 'Refresh'
      iv_act = c_action-refresh ).

    ro_toolbar->add(
      iv_txt = 'Consolidate'
      iv_act = c_action-consolidate ).

    ro_toolbar->add(
      iv_txt = zcl_abapgit_gui_buttons=>repo_list( )
      iv_act = zif_abapgit_definitions=>c_action-abapgit_home ).

    ro_toolbar->add(
      iv_txt = 'Back'
      iv_act = zif_abapgit_definitions=>c_action-go_back ).

  ENDMETHOD.


  METHOD zif_abapgit_gui_renderable~render.

    DATA ls_feature    LIKE LINE OF mt_features.
    DATA lv_index      TYPE i.
    DATA lv_rendered   TYPE abap_bool.
    DATA lv_icon_class TYPE string.
    DATA lo_timer      TYPE REF TO zcl_abapgit_timer.


    lo_timer = zcl_abapgit_timer=>create( )->start( ).

    register_handlers( ).
    CREATE OBJECT ri_html TYPE zcl_abapgit_html.
    ri_html->add( '<div class="repo-overview">' ).

    IF mt_features IS INITIAL.
      mt_features = zcl_abapgit_flow_logic=>get( ).
    ENDIF.



    ri_html->add( '<span class="toolbar-light pad-sides">' ).

    " todo IF ms_user_settings-only_my_transports = abap_true.
    " todo   lv_icon_class = `blue`.
    " todo ELSE.
    " todo   lv_icon_class = `grey`.
    " todo ENDIF.
    " todo ri_html->add( ri_html->a(
    " todo   iv_txt   = |<i id="icon-filter-favorite" class="icon icon-check { lv_icon_class }"></i> Only my transports|
    " todo   iv_class = 'command'
    " todo   iv_act   = |{ c_action-only_my_transports }| ) ).

    IF ms_user_settings-hide_full_matches = abap_true.
      lv_icon_class = `blue`.
    ELSE.
      lv_icon_class = `grey`.
    ENDIF.
    ri_html->add( ri_html->a(
      iv_txt   = |<i id="icon-filter-favorite" class="icon icon-check { lv_icon_class }"></i> Hide full matches|
      iv_class = 'command'
      iv_act   = |{ c_action-hide_full_matches }| ) ).

    IF ms_user_settings-hide_matching_files = abap_true.
      lv_icon_class = `blue`.
    ELSE.
      lv_icon_class = `grey`.
    ENDIF.
    ri_html->add( ri_html->a(
      iv_txt   = |<i id="icon-filter-favorite" class="icon icon-check { lv_icon_class }"></i> Hide matching files|
      iv_class = 'command'
      iv_act   = |{ c_action-hide_matching_files }| ) ).

    ri_html->add( '</span>' ).

    ri_html->add( '<br>' ).
    ri_html->add( '<br>' ).

    LOOP AT mt_features INTO ls_feature.
      lv_index = sy-tabix.

      IF ms_user_settings-hide_full_matches = abap_true
          AND ls_feature-full_match = abap_true.
        CONTINUE.
      ENDIF.

      IF lines( ls_feature-changed_files ) = 0.
* no changes, eg. only files outside of starting folder changed
        CONTINUE.
      ENDIF.
      lv_rendered = abap_true.

      ri_html->add( '<b><font size="+2">' && ls_feature-repo-name ).
      IF ls_feature-branch-display_name IS NOT INITIAL.
        ri_html->add( | - | ).
        ri_html->add_icon( 'code-branch' ).
        ri_html->add( ls_feature-branch-display_name ).
      ENDIF.
      IF ls_feature-transport-trkorr IS NOT INITIAL.
        ri_html->add( | - | ).
        ri_html->add_icon( 'truck-solid' ).
        ri_html->add( |<tt>{ ls_feature-transport-trkorr }</tt>| ).
      ENDIF.
      ri_html->add( |</font></b><br>| ).

      IF ls_feature-branch-display_name IS INITIAL.
        ri_html->add( |No branch found, comparing with <tt>main</tt>| ).
      ELSEIF ls_feature-pr IS NOT INITIAL.
        ri_html->add_a(
          iv_txt   = ls_feature-pr-title
          iv_act   = |{ zif_abapgit_definitions=>c_action-url }?url={ ls_feature-pr-url }|
          iv_class = |url| ).

        IF ls_feature-pr-draft = abap_true.
          ri_html->add( 'DRAFT' ).
        ENDIF.
      ELSE.
        ri_html->add( |No PR found| ).
      ENDIF.
      ri_html->add( |<br>| ).

      IF ls_feature-transport IS NOT INITIAL.
        ri_html->add( |<tt>{ ls_feature-transport-trkorr }</tt> - { ls_feature-transport-title }<br>| ).
      ELSE.
        ri_html->add( |No corresponding transport found<br>| ).
      ENDIF.

      IF ls_feature-branch IS NOT INITIAL AND ls_feature-branch-up_to_date = abap_false.
        ri_html->add( '<b>Branch not up to date</b><br><br>' ).
        CONTINUE.
      ENDIF.

      ri_html->add( render_toolbar(
        iv_index   = lv_index
        is_feature = ls_feature ) ).

      IF ls_feature-full_match = abap_true.
        ri_html->add( |Full Match, {
          lines( ls_feature-changed_files ) } files, {
          lines( ls_feature-changed_objects ) } objects<br>| ).
      ELSE.
        ri_html->add( render_table( ls_feature ) ).
      ENDIF.

* todo      LOOP AT ls_feature-changed_objects INTO ls_item.
* todo       ri_html->add( |<tt><small>{ ls_item-obj_type } { ls_item-obj_name }</small></tt><br>| ).
* todo     ENDLOOP.

      ri_html->add( '<br>' ).
    ENDLOOP.

    IF lines( mt_features ) = 0 OR lv_rendered = abap_false.
      ri_html->add( 'Empty, repositories must be favorite + flow enabled<br><br>' ).

      ri_html->add( 'Or nothing in progress<br><br>' ).

      ri_html->add_a(
        iv_txt   = 'abapGit flow documentation'
        iv_act   = |{ zif_abapgit_definitions=>c_action-url
          }?url=https://docs.abapgit.org/user-guide/reference/flow.html|
        iv_class = |url| ).
    ELSE.
      ri_html->add( |<small>{ lines( mt_features ) } features in { lo_timer->end( ) }</small>| ).
    ENDIF.

    ri_html->add( '</div>' ).

  ENDMETHOD.
ENDCLASS.

CLASS lhc_booking DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    "==================== AUTHORIZATION ====================
    " ( global ) -> kiểm theo THAO TÁC (C/U/D), không cần đọc dữ liệu record
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Booking RESULT result.

    " ( instance ) -> kiểm theo TỪNG RECORD (dựa dữ liệu). BẮT BUỘC vì BDEF khai ( global, instance )
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Booking RESULT result.

    "==================== NUMBERING ====================
    " early numbering -> cấp BookingId ('BKnnnn') ở interaction phase
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Booking.

    "==================== ACTIONS ====================
    " instance action, RESULT result -> khớp 'result [1] $self' trong BDEF
    METHODS acceptBooking FOR MODIFY
      IMPORTING keys FOR ACTION Booking~acceptBooking RESULT result.
    METHODS cancelBooking FOR MODIFY
      IMPORTING keys FOR ACTION Booking~cancelBooking RESULT result.
    " action có tham số -> đọc qua keys[...]-%param
    METHODS applyDiscount FOR MODIFY
      IMPORTING keys FOR ACTION Booking~applyDiscount RESULT result.

ENDCLASS.


CLASS lhc_booking IMPLEMENTATION.

  "==================================================================
  " GLOBAL AUTHORIZATION - có được phép C/U/D nói chung không?
  "==================================================================
  METHOD get_global_authorizations.
    " Buổi 4: cho phép tất cả (siết quyền thật bằng AUTHORITY-CHECK -> buổi nâng cao).
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    result-%delete = if_abap_behv=>auth-allowed.
  ENDMETHOD.

  "==================================================================
  " INSTANCE AUTHORIZATION - có được phép trên ĐÚNG record này không?
  "==================================================================
  METHOD get_instance_authorizations.
    " Rule demo: booking đã Cancelled ('X') -> cấm update/delete.
    READ ENTITIES OF zi_booking_fs01 IN LOCAL MODE
      ENTITY Booking FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt) FAILED failed.

    result = VALUE #( FOR b IN lt (
      %tky    = b-%tky
      %update = COND #( WHEN b-OverallStatus = 'X'
                        THEN if_abap_behv=>auth-unauthorized ELSE if_abap_behv=>auth-allowed )
      %delete = COND #( WHEN b-OverallStatus = 'X'
                        THEN if_abap_behv=>auth-unauthorized ELSE if_abap_behv=>auth-allowed )
    ) ).
  ENDMETHOD.

  "==================================================================
  " EARLY NUMBERING - cấp BookingId semantic key char(10): 'BK0001'...
  "==================================================================
  METHOD earlynumbering_create.
    SELECT SINGLE FROM zbooking_fs01 FIELDS MAX( booking_id ) INTO @DATA(lv_max_id).
    DATA(lv_num) = COND i( WHEN lv_max_id IS INITIAL THEN 0 ELSE CONV i( lv_max_id+2 ) ).

    LOOP AT entities INTO DATA(entity) WHERE BookingId IS INITIAL.
      lv_num += 1.
      APPEND VALUE #( %cid      = entity-%cid        " liên kết về instance vừa create
                      %is_draft = entity-%is_draft   " cần cho BO có draft
                      BookingId = |BK{ lv_num ALIGN = RIGHT PAD = '0' WIDTH = 4 }| )
        TO mapped-booking.
    ENDLOOP.
  ENDMETHOD.

  "==================================================================
  " ACTION acceptBooking - set status 'A' (Accepted). EML nội bộ, KHÔNG COMMIT.
  "==================================================================
  METHOD acceptBooking.
    " IN LOCAL MODE = bỏ qua vòng kiểm quyền/DCL (đã kiểm ở ngoài), tránh đệ quy.
    MODIFY ENTITIES OF zi_booking_fs01 IN LOCAL MODE
      ENTITY Booking
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky  OverallStatus = 'A' ) )
      FAILED   failed
      REPORTED reported.

    " Trả $self để Fiori refresh dòng vừa đổi.
    READ ENTITIES OF zi_booking_fs01 IN LOCAL MODE
      ENTITY Booking ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_booking).
    result = VALUE #( FOR b IN lt_booking ( %tky = b-%tky  %param = b ) ).
  ENDMETHOD.

  "==================================================================
  " ACTION cancelBooking - set status 'X' (Cancelled).
  "==================================================================
  METHOD cancelBooking.
    MODIFY ENTITIES OF zi_booking_fs01 IN LOCAL MODE
      ENTITY Booking
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky  OverallStatus = 'X' ) )
      FAILED failed REPORTED reported.

    READ ENTITIES OF zi_booking_fs01 IN LOCAL MODE
      ENTITY Booking ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_booking).
    result = VALUE #( FOR b IN lt_booking ( %tky = b-%tky  %param = b ) ).
  ENDMETHOD.

  "==================================================================
  " ACTION applyDiscount(%param-DiscountPct) - giảm TotalPrice theo %.
  "==================================================================
  METHOD applyDiscount.
    " Đọc giá hiện tại.
    READ ENTITIES OF zi_booking_fs01 IN LOCAL MODE
      ENTITY Booking FIELDS ( TotalPrice ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_booking).

    DATA lt_update TYPE TABLE FOR UPDATE zi_booking_fs01.
    LOOP AT lt_booking INTO DATA(ls).
      " %param mang tham số action (abstract entity ZA_BOOKING_DISC_FS01).
      DATA(lv_pct) = keys[ KEY entity %tky = ls-%tky ]-%param-DiscountPct.
      APPEND VALUE #( %tky       = ls-%tky
                      TotalPrice = ls-TotalPrice * ( 100 - lv_pct ) / 100
                    ) TO lt_update.
    ENDLOOP.

    " Ghi giá mới vào buffer (framework tự save khi user Save).
    MODIFY ENTITIES OF zi_booking_fs01 IN LOCAL MODE
      ENTITY Booking UPDATE FIELDS ( TotalPrice ) WITH lt_update.

    READ ENTITIES OF zi_booking_fs01 IN LOCAL MODE
      ENTITY Booking ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res).
    result = VALUE #( FOR b IN lt_res ( %tky = b-%tky  %param = b ) ).
  ENDMETHOD.

ENDCLASS.

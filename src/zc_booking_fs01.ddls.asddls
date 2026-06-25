@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection Booking'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_BOOKING_FS01
  provider contract transactional_query
  as projection on zi_booking_fs01
{
  key BookingId,
      CustomerId,
      BookingDate,
      Description,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalPrice,
      CurrencyCode,
      OverallStatus,

      /* Associations */
      _bookingItem
}

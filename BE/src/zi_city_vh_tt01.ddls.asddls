@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'City - Value Help (distinct)'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_CITY_VH_TT01
  as select distinct from zcustomer_TT01
{
      -- distinct city list from the customer master
  key city as City
}

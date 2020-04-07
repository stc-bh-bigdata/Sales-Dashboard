<<<<<<< HEAD
	  
-------------------------------------------------------- From Hue 8-Dec-2019
  
  ---------------------------------------- Unique Products for MDS Sep-Nov Month ------------------------------------------------------------
drop table test_db.UniqueProducts_Sep_onwards;

Create table test_db.UniqueProducts_Sep_onwards AS
SELECT distinct orditm.prod_id as productid, prod.productname as product, prod.stcservicetype product_type
FROM bdl_raw.crm_s_order_item_1 orditm  -- the most garngular table at order line item level
left outer join bdl_dm.dimsubscriber san on orditm.serv_accnt_id = san.subscriberid
left outer join bdl_dm.dimbillingaccount ban  on san.billingaccountid = ban.billingaccountid
left outer join bdl_raw.crm_s_order_1 ord  on ord.row_id = orditm.order_id
left outer join bdl_dm.dimproduct prod on prod.productid = orditm.prod_id
WHERE ban.customertype = 'Individual' 
and ord.X_SUB_TYPE in ('Provide','Modify','Migration')
and ord.status_cd = 'Complete' 
and orditm.action_cd in ('Add','Delete')
and to_date(from_utc_timestamp(ord.Created,'Asia/Bahrain')) >= '2019-08-31'
;

  
------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%------ %%%%%%%%%%%%% New MDS currently used for PoC ------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%------ 
drop table test_db.dimarticledetails;

Create external table test_db.dimarticledetails
(
productid               STRING,
productname             STRING,
commercialproductname   STRING ,
level3                  STRING,
level4                  STRING,
Description             STRING,
facevalue               FLOAT, 
level3_order            INT  
)
row format delimited fields terminated by ',' location '/user/kmahgoub/Sales/MDS_27Nov';

refresh test_db.dimarticledetails;

  
------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%------ %%%%%%%%%%%%% Shop MDS ------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%

drop table test_db.dimshops;

Create external table test_db.dimshops
(
ShopName	STRING ,
Area	        STRING ,   
ShopType	STRING ,
Longitude	FLOAT ,
Latitude	FLOAT ,
Area1           STRING ,
Type	        STRING ,
Counters        INT
)
row format delimited fields terminated by ',' location '/user/kmahgoub/Shops';

refresh test_db.dimshops;

--------- new table

drop table test_db.Base_Table_Sep_onwards;
Create table test_db.Base_Table_Sep_onwards AS
SELECT  from_utc_timestamp(ord.created,'Asia/Bahrain') as transactiondate,
       orditm.row_id ,
       san.subscriberid,
       san.serviceaccountname as customername,
	   san.connectiontype,
       ban.linecategory AS LineCategory,
       san.msisdn as msisdn,
       ord.order_num as orderid,
       (CASE WHEN ord.x_sub_type = 'Provide'
            THEN 'New'
        END) as transactiontype_level1,
	   'ServicePlan' AS transactionsubtype_level2,
       ord.created As contractstartdate,
       orditm.prod_id as productrowid,
       prod.name as product,
       prod.body_style_cd as crmproducttype,
       prod.part_num as productpartnumber,
       orditm.net_pri as netprice,
       ord.x_sub_type as ordertype,
       orditm.status_cd as orderitemstatus,
       orditm.action_cd as actioncd,
       ord.status_cd as orderstatus,
       orditmom.service_start_dt as servicestartdate,
        round(datediff(orditmom.service_end_dt,ord.created)/30.417,0) as Duration,
        orditmom.service_end_dt as serviceenddate,
        san.serviceaccountnumber,
	ban.billingaccountnumber,
        orditm.row_id as orderitemrowid,
        orditm.par_order_item_id as parentorderitemrowid,
        orditm.asset_integ_id,
		usr.login,
		usr.username,
		ord2.x_shop_id as shopname,
		ord2.x_mena_user as MenaIdentifier,x_channel
		--- new columns
,dim.level3,	dim.level4,	dim.facevalue,	dim.level3_order , dim.description 
, case when dim.level3 in ('Accessories','Device') then 'HW' else dim.level3 end HW_Flag
  FROM bdl_raw.crm_s_order_item_1 orditm
   left outer join bdl_dm.dimsubscriber san
       on orditm.serv_accnt_id = san.subscriberid
   left outer join bdl_dm.dimbillingaccount ban
       on san.billingaccountid = ban.billingaccountid
   left outer join bdl_raw.crm_s_order_1 ord
       on ord.row_id = orditm.order_id
    left outer join    (select * from ( select ROW_NUMBER() OVER(partition by row_id order by last_upd desc) Rank  
   , *  FROM bdl_raw.crm_s_order_item_om) a where rank = 1) orditmom on orditm.row_id = orditmom.row_id
    left outer join bdl_raw.crm_s_prod_int_1 prod
     on orditm.prod_id = prod.row_id
    left outer join bdl_dm.dimuser usr
     on ord.created_by = usr.userid
    left outer join bdl_raw.crm_s_order_2 ord2
     on ord.row_id = ord2.row_id
          --- new join with MDS table
inner join test_db.dimarticledetails dim on orditm.prod_id = dim.productid
   WHERE   ban.customertype = 'Individual'
      and ord.X_SUB_TYPE in ('Provide','Modify','Migration')
	  and ord.status_cd = 'Complete'
	  and orditm.status_cd = 'Complete'
	  and dim.level3 <> 'Exclude'
	  and orditm.action_cd in ('Add','Delete')
      and to_date(from_utc_timestamp(ord.Created,'Asia/Bahrain')) >= '2019-08-31'
      ;

--- deleted items enrichment
drop table test_db.Base_Table_Delete_Sep_onwards;
Create table test_db.Base_Table_Delete_Sep_onwards AS
select case 
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=0 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=0 then 'Service' 
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=0 then 'Service & Device'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=1 and regexp_like(agg.level3, 'Other')=0 then 'Service, Device & Accessories'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=0 and regexp_like(agg.level3, 'Accessories')=1 and regexp_like(agg.level3, 'Other')=0 then 'Service & Accessories'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=1 then 'Service, Device & Others'
when agg.level3 = 'Other' then 'Other' when agg.level3 = 'Device' then 'Device' when agg.level3 = 'Service' then 'Service'  when agg.level3 = 'Accessories' then 'Accessories' else 'Misc' end Level3_Category_Case,
a.transactiondate	,	a.subscriberid	,	a.customername	,	a.linecategory	,a.msisdn	,	a.orderid	,	a.contractstartdate	,	
a.product	,	b.product	old_product_name	,
a.netprice	,	b.netprice	old_netprice	,
a.ordertype	,	a.actioncd	,	a.servicestartdate	,	a.duration	,	
a.serviceenddate	,	b.serviceenddate	old_serviceenddate	,
a.login	,	a.username	,  a.shopname	,	a.x_channel	,	
a.level3	,	b.level3	old_level3	,
a.level4	,	b.level4	old_level4	,
a.facevalue	,	b.facevalue	old_facevalue	,
a.level3_order	,	a.description	
 from  test_db.Base_Table_Sep_onwards a 
left outer join  test_db.Base_Table_Sep_onwards b on a.orderid = b.orderid and a.HW_Flag = b.HW_Flag      
left outer join (select orderid, group_concat(distinct level3) as level3 from (select a.* from 
(select a.level3 , a.orderid from test_db.Base_Table_Sep_onwards a where a.level3 in ('Service','Accessories','Device','Other')) a ) b 
group by orderid) agg on a.orderid = agg.orderid
where a.level3 <> 'Exclude' and b.level3 <> 'Exclude' and a.actioncd = 'Add' and b.actioncd = 'Delete' 
--- updated on 14th Jan
and a.ordertype <> 'Provide'
union all
select 
case 
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=0 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=0 then 'Service' 
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=0 then 'Service & Device'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=1 and regexp_like(agg.level3, 'Other')=0 then 'Service, Device & Accessories'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=0 and regexp_like(agg.level3, 'Accessories')=1 and regexp_like(agg.level3, 'Other')=0 then 'Service & Accessories'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=1 then 'Service, Device & Others'
when agg.level3 = 'Other' then 'Other' when agg.level3 = 'Device' then 'Device' when agg.level3 = 'Service' then 'Service'  when agg.level3 = 'Accessories' then 'Accessories' else 'Misc' end Level3_Category_Case,
a.transactiondate	,	a.subscriberid	,	a.customername	,	a.linecategory	,a.msisdn	,	a.orderid	,	a.contractstartdate	,	
a.product	,	null	old_product_name	,
a.netprice	,	0	old_netprice	,
a.ordertype	,	a.actioncd	,	a.servicestartdate	,	a.duration	,	
a.serviceenddate	,	null	old_serviceenddate	,
a.login	,	a.username	,  a.shopname	,	a.x_channel	,	
a.level3	,	null	old_level3	,
a.level4	,	null	old_level4	,
a.facevalue	,	0	old_facevalue	,
a.level3_order	,	a.description	
from  test_db.Base_Table_Sep_onwards a 
--left outer join  test_db.Base_Table_Sep_onwards b on a.orderid = b.orderid and a.HW_Flag = b.HW_Flag      
left outer join (select orderid, group_concat(distinct level3) as level3 from (select a.* from 
(select a.level3 , a.orderid from test_db.Base_Table_Sep_onwards a where a.level3 in ('Service','Accessories','Device','Other')) a ) b 
group by orderid) agg on a.orderid = agg.orderid
where a.level3 <> 'Exclude' 
and a.ordertype = 'Provide';

-- ***************************************************************************************
-- **************************** - Deriveid Logic for Report - ****************************
-- ***************************************************************************************

-- **************************** - Level 1 logic ****************************

--made it into one table 
--  ******************* Device only transactions  *******************
Drop table test_db.Base_Table_Sep_onwards_Pre;

Create table test_db.Base_Table_Sep_onwards_Pre as
select --orderid ,ordertype,productname ,  facevalue , old_product_name , old_facevalue,old_serviceenddate,level3,
datediff(old_serviceenddate,transactiondate) daysdiff,
-- upgrade scenarios
case when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
     when ordertype <> 'Provide' and old_product_name is not null and  (datediff(old_serviceenddate,transactiondate) > 90 
     or datediff(old_serviceenddate,transactiondate) < -90) then 'Upgrade'
--when nvl(facevalue,0)- nvl(old_facevalue,0) < 0 and (productname is not null and level3 = 'Device')  then 'Upgrade'
-- downgrade scenarios
--when nvl(facevalue,0)- nvl(old_facevalue,0) < 0 and (productname is     null and level3 = 'Device')  then 'Downgrade'
when ordertype <> 'Provide' and old_product_name is null     then 'Upgrade'
when ordertype =  'Provide' and old_product_name is not null then 'Provide with old device to be investigated'
when ordertype =  'Provide' and old_product_name is null then 'New'
else 'check' end Level1, *
from test_db.Base_Table_Delete_Sep_onwards where level3 = 'Device' 
--- ******************* Accessories only  *******************
union all
select --orderid ,ordertype,productname ,  facevalue , old_product_name , old_facevalue,old_serviceenddate,level3,
datediff(old_serviceenddate,transactiondate) daysdiff,
-- upgrade scenarios
case when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
     when ordertype <> 'Provide' and old_product_name is not null and  (datediff(old_serviceenddate,transactiondate) > 90 
     or datediff(old_serviceenddate,transactiondate) < -90) then 'Upgrade'
when ordertype <> 'Provide' and old_product_name is null     then 'Upgrade'
when ordertype =  'Provide' and old_product_name is not null then 'Provide with old acc to be investigated'
when ordertype =  'Provide' and old_product_name is     null then 'New'
else 'check' end xGrade, *
from test_db.Base_Table_Delete_Sep_onwards where level3 = 'Accessories'  
--  ******************* other than devices and acc transactions  *******************
union all
select datediff(old_serviceenddate,transactiondate) daysdiff,
-- upgrade scenarios
case --when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
     --when ordertype <> 'Provide' and old_product_name is not null and  (datediff(old_serviceenddate,transactiondate) > 90 or datediff(old_serviceenddate,transactiondate) < -90) then 'Upgrade'
    when lower(product) like '%temp%' then 'Termination Request'
    when lower(old_product_name) like '%temp%' then 'Retention'
    when ordertype = 'Migration' then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) < 0  and serviceenddate is not null then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) < 0 then 'Downgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) > 0 then 'Upgrade'
    when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) = 0 and serviceenddate is not null then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) = 0 then 'Same face value'
    when ordertype = 'Provide' then 'New' else 'check' end xGrade, *
from test_db.Base_Table_Delete_Sep_onwards where level3 = 'Service'  
and orderid not in (select distinct orderid from test_db.Base_Table_Delete_Sep_onwards where level3  in ('Accessories','Device','Other'))
--  ******************* other procuts (i.e. shared sims)  *******************
union all
select datediff(old_serviceenddate,transactiondate) daysdiff,
-- upgrade scenarios
case when lower(product) like '%temp%' then 'Termination Request'
    when lower(old_product_name) like '%temp%' then 'Retention'
    when ordertype = 'Migration' then 'Upgrade Migration'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) < 0  and serviceenddate is not null then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) < 0 then 'Downgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) > 0 then 'Upgrade'
    when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) = 0 and serviceenddate is not null then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) = 0 then 'Same face value'
    when ordertype = 'Provide' then 'New'
else 'check' end xGrade, *
from test_db.Base_Table_Delete_Sep_onwards where level3 = 'Other' 
and orderid not in (select distinct orderid from test_db.Base_Table_Delete_Sep_onwards where level3  in ('Accessories','Device','Service'));


------ combining back all sub-tables

Drop table test_db.Base_Table_Sep_onwards_RPT;

Create table test_db.Base_Table_Sep_onwards_RPT AS
select distinct b.Level1 ,
case when level4 = 'ChildSim' then 'Child SIM'
     when level1 = 'Upgrade' and ordertype= 'Migration' and lower(product) not like '%prepaid%' then 'Pre2Post' 
     when level1 = 'Downgrade' and ordertype= 'Migration' and lower(product) like '%prepaid%' then 'Pre2Post' 
     when level1 = 'Upgrade' and nvl(facevalue,0)- nvl(old_facevalue,0) > 0 and serviceenddate is null then 'Post2Post'
     when serviceenddate is not null then 'Contractual'
     when serviceenddate is null and level3_category_case <> 'Service'  then 'Contractual'
     when serviceenddate is null then 'SIM only'  end Level2,
     case when x_channel = "eCommerce" then "E-Shop" when x_channel = "mapp" then "App" else nvl(a.shopname,'Outbound_NVL') end Shop_CRM ,
     a.* , to_date(transactiondate) as SalesDate , hour(transactiondate) as SalesHour 
 , pos_tr.agentid Agent_POS, pos_tr.shop Shop_POS , pos_tr.agent_firstname Agent_Name_POS
 , pos_subid.agentid Agent_POS_SubID , pos_subid.shop Shop_POS_SubID 
, dealer_name Dealer
, pos_subid.transaction_date POS_Timestamp
from test_db.Base_Table_Delete_Sep_onwards a 
left outer join -- level 1 tagging
(select distinct orderid , level1 from test_db.Base_Table_Sep_onwards_Pre) b on a.orderid = b.orderid
 left outer join --- POS CRM Trigger (proxy for below table)
bdl_analytics.triggers_posorderdetails_vw pos on pos.crm_order = a.orderid
left outer join  --- POS trigger join based on Journal ID
bdl_analytics.triggers_grosssales_vw pos_tr on pos.journal_id = pos_tr.journal_id  
left outer join --- POS join based on SubscriberID transaction within 10 hours
bdl_analytics.triggers_grosssales_vw pos_subid on a.subscriberid = pos_subid.subscriberid
and  abs((cast(pos_subid.transaction_date as bigint) - cast(from_utc_timestamp(a.transactiondate,'Asia/Bahrain') as bigint))/60) < 600
left outer join --- MPos delaer details
(SELECT order_num ,Attrib_45 dealer_name FROM  bdl_raw.crm_s_order_1 a , bdl_raw.crm_s_order_x b 
where a.row_id = b.row_id and Attrib_45 is NOT NULL and  x_sub_status = 'Complete') dealer on dealer.order_num = a.orderid;

---- Main table

Drop   table test_db.Base_Table_Sep_onwards_RPT_Cash;

Create table test_db.Base_Table_Sep_onwards_RPT_Cash AS
select a.* , 
---- shop name 
case when username is null and Shop_POS is null then login 
     when shop_crm in ('E-Shop','App') then shop_crm else isnull(Shop_POS,isnull(Shop_POS_SubID,shop_crm)) end ShopNameCombined
--- enrich with SubDim
, b.subscribertypename from
(select * from test_db.Base_Table_Sep_onwards_RPT
union all
---- POS only (shows everything) -> delta is cash sales or zero price sales
--- Cash only
SELECT 'Cash' Level1,  articlegroup Level2,  '' shop_crm , '' level3_category_case  ,   cash_day transactiondate, subscriberid, '' customername,
'' linecategory , msisdn, journal_id orderid, '' contractstartdate, articlename Product, '' old_product_name,  cast(item_total_amount as INT) netprice , 0 old_netprice, '' ordertype
, '' actioncd , '' serviceenddate , transaction_amount duration , '' servicestartdate, '' old_serviceenddate ,'' login , '' username , '' shopname , '' x_channel, '' level3 , '' old_level3
 ,'' level4, '' old_level4 , 0 facevalue, 0 old_facevalue , 0 level3_order , '' description , to_date(cash_day) salesdate , hour(cash_day) SalesHour
 , agentid Agent_POS,  shop Shop_POS, agent_firstname Agent_Name_POS  , '' pos_agent_subid	, '' Shop_POS_SubID , '' dealer   , '' pos_timestamp			
FROM bdl_analytics.triggers_grosssales_vw 
where articlegroup in ('ETOPUP','Recharge Cards','Accessories') and 
to_date(transaction_date) >= '2019-08-31' --and to_date(transaction_date) < '2019-12-01'
and concat(nvl(articleno,'x'),nvl(Journal_id,'x')) not in 
(SELECT concat(nvl(articleno,'x'),nvl(Journal_id,'x'))  FROM bdl_analytics.triggers_posorderdetails_vw
where  to_date(order_completion_date) >= '2019-08-31' 
)) a 
left outer join bdl_rpt.powerbidimsubscriber b on a.subscriberid = b.subscriberid  ;

--------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------- END ----------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------


=======
	  
-------------------------------------------------------- From Hue 8-Dec-2019
  
  ---------------------------------------- Unique Products for MDS Sep-Nov Month ------------------------------------------------------------
drop table test_db.UniqueProducts_Sep_onwards;

Create table test_db.UniqueProducts_Sep_onwards AS
SELECT distinct orditm.prod_id as productid, prod.productname as product, prod.stcservicetype product_type
FROM bdl_raw.crm_s_order_item_1 orditm  -- the most garngular table at order line item level
left outer join bdl_dm.dimsubscriber san on orditm.serv_accnt_id = san.subscriberid
left outer join bdl_dm.dimbillingaccount ban  on san.billingaccountid = ban.billingaccountid
left outer join bdl_raw.crm_s_order_1 ord  on ord.row_id = orditm.order_id
left outer join bdl_dm.dimproduct prod on prod.productid = orditm.prod_id
WHERE ban.customertype = 'Individual' 
and ord.X_SUB_TYPE in ('Provide','Modify','Migration')
and ord.status_cd = 'Complete' 
and orditm.action_cd in ('Add','Delete')
and to_date(from_utc_timestamp(ord.Created,'Asia/Bahrain')) >= '2019-08-31'
;

  
------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%------ %%%%%%%%%%%%% New MDS currently used for PoC ------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%------ 
drop table test_db.dimarticledetails;

Create external table test_db.dimarticledetails
(
productid               STRING,
productname             STRING,
commercialproductname   STRING ,
level3                  STRING,
level4                  STRING,
Description             STRING,
facevalue               FLOAT, 
level3_order            INT  
)
row format delimited fields terminated by ',' location '/user/kmahgoub/Sales/MDS_27Nov';

refresh test_db.dimarticledetails;

  
------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%------ %%%%%%%%%%%%% Shop MDS ------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%------ %%%%%%%%%%%%%

drop table test_db.dimshops;

Create external table test_db.dimshops
(
ShopName	STRING ,
Area	        STRING ,   
ShopType	STRING ,
Longitude	FLOAT ,
Latitude	FLOAT ,
Area1           STRING ,
Type	        STRING ,
Counters        INT
)
row format delimited fields terminated by ',' location '/user/kmahgoub/Shops';

refresh test_db.dimshops;

--------- new table

drop table test_db.Base_Table_Sep_onwards;
Create table test_db.Base_Table_Sep_onwards AS
SELECT  from_utc_timestamp(ord.created,'Asia/Bahrain') as transactiondate,
       orditm.row_id ,
       san.subscriberid,
       san.serviceaccountname as customername,
	   san.connectiontype,
       ban.linecategory AS LineCategory,
       san.msisdn as msisdn,
       ord.order_num as orderid,
       (CASE WHEN ord.x_sub_type = 'Provide'
            THEN 'New'
        END) as transactiontype_level1,
	   'ServicePlan' AS transactionsubtype_level2,
       ord.created As contractstartdate,
       orditm.prod_id as productrowid,
       prod.name as product,
       prod.body_style_cd as crmproducttype,
       prod.part_num as productpartnumber,
       orditm.net_pri as netprice,
       ord.x_sub_type as ordertype,
       orditm.status_cd as orderitemstatus,
       orditm.action_cd as actioncd,
       ord.status_cd as orderstatus,
       orditmom.service_start_dt as servicestartdate,
        round(datediff(orditmom.service_end_dt,ord.created)/30.417,0) as Duration,
        orditmom.service_end_dt as serviceenddate,
        san.serviceaccountnumber,
	ban.billingaccountnumber,
        orditm.row_id as orderitemrowid,
        orditm.par_order_item_id as parentorderitemrowid,
        orditm.asset_integ_id,
		usr.login,
		usr.username,
		ord2.x_shop_id as shopname,
		ord2.x_mena_user as MenaIdentifier,x_channel
		--- new columns
,dim.level3,	dim.level4,	dim.facevalue,	dim.level3_order , dim.description 
, case when dim.level3 in ('Accessories','Device') then 'HW' else dim.level3 end HW_Flag
  FROM bdl_raw.crm_s_order_item_1 orditm
   left outer join bdl_dm.dimsubscriber san
       on orditm.serv_accnt_id = san.subscriberid
   left outer join bdl_dm.dimbillingaccount ban
       on san.billingaccountid = ban.billingaccountid
   left outer join bdl_raw.crm_s_order_1 ord
       on ord.row_id = orditm.order_id
    left outer join    (select * from ( select ROW_NUMBER() OVER(partition by row_id order by last_upd desc) Rank  
   , *  FROM bdl_raw.crm_s_order_item_om) a where rank = 1) orditmom on orditm.row_id = orditmom.row_id
    left outer join bdl_raw.crm_s_prod_int_1 prod
     on orditm.prod_id = prod.row_id
    left outer join bdl_dm.dimuser usr
     on ord.created_by = usr.userid
    left outer join bdl_raw.crm_s_order_2 ord2
     on ord.row_id = ord2.row_id
          --- new join with MDS table
inner join test_db.dimarticledetails dim on orditm.prod_id = dim.productid
   WHERE   ban.customertype = 'Individual'
      and ord.X_SUB_TYPE in ('Provide','Modify','Migration')
	  and ord.status_cd = 'Complete'
	  and orditm.status_cd = 'Complete'
	  and dim.level3 <> 'Exclude'
	  and orditm.action_cd in ('Add','Delete')
      and to_date(from_utc_timestamp(ord.Created,'Asia/Bahrain')) >= '2019-08-31'
      ;

--- deleted items enrichment
drop table test_db.Base_Table_Delete_Sep_onwards;
Create table test_db.Base_Table_Delete_Sep_onwards AS
select case 
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=0 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=0 then 'Service' 
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=0 then 'Service & Device'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=1 and regexp_like(agg.level3, 'Other')=0 then 'Service, Device & Accessories'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=0 and regexp_like(agg.level3, 'Accessories')=1 and regexp_like(agg.level3, 'Other')=0 then 'Service & Accessories'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=1 then 'Service, Device & Others'
when agg.level3 = 'Other' then 'Other' when agg.level3 = 'Device' then 'Device' when agg.level3 = 'Service' then 'Service'  when agg.level3 = 'Accessories' then 'Accessories' else 'Misc' end Level3_Category_Case,
a.transactiondate	,	a.subscriberid	,	a.customername	,	a.linecategory	,a.msisdn	,	a.orderid	,	a.contractstartdate	,	
a.product	,	b.product	old_product_name	,
a.netprice	,	b.netprice	old_netprice	,
a.ordertype	,	a.actioncd	,	a.servicestartdate	,	a.duration	,	
a.serviceenddate	,	b.serviceenddate	old_serviceenddate	,
a.login	,	a.username	,  a.shopname	,	a.x_channel	,	
a.level3	,	b.level3	old_level3	,
a.level4	,	b.level4	old_level4	,
a.facevalue	,	b.facevalue	old_facevalue	,
a.level3_order	,	a.description	
 from  test_db.Base_Table_Sep_onwards a 
left outer join  test_db.Base_Table_Sep_onwards b on a.orderid = b.orderid and a.HW_Flag = b.HW_Flag      
left outer join (select orderid, group_concat(distinct level3) as level3 from (select a.* from 
(select a.level3 , a.orderid from test_db.Base_Table_Sep_onwards a where a.level3 in ('Service','Accessories','Device','Other')) a ) b 
group by orderid) agg on a.orderid = agg.orderid
where a.level3 <> 'Exclude' and b.level3 <> 'Exclude' and a.actioncd = 'Add' and b.actioncd = 'Delete' 
--- updated on 14th Jan
and a.ordertype <> 'Provide'
union all
select 
case 
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=0 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=0 then 'Service' 
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=0 then 'Service & Device'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=1 and regexp_like(agg.level3, 'Other')=0 then 'Service, Device & Accessories'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=0 and regexp_like(agg.level3, 'Accessories')=1 and regexp_like(agg.level3, 'Other')=0 then 'Service & Accessories'
when regexp_like(agg.level3, 'Service')=1 and regexp_like(agg.level3, 'Device')=1 and regexp_like(agg.level3, 'Accessories')=0 and regexp_like(agg.level3, 'Other')=1 then 'Service, Device & Others'
when agg.level3 = 'Other' then 'Other' when agg.level3 = 'Device' then 'Device' when agg.level3 = 'Service' then 'Service'  when agg.level3 = 'Accessories' then 'Accessories' else 'Misc' end Level3_Category_Case,
a.transactiondate	,	a.subscriberid	,	a.customername	,	a.linecategory	,a.msisdn	,	a.orderid	,	a.contractstartdate	,	
a.product	,	null	old_product_name	,
a.netprice	,	0	old_netprice	,
a.ordertype	,	a.actioncd	,	a.servicestartdate	,	a.duration	,	
a.serviceenddate	,	null	old_serviceenddate	,
a.login	,	a.username	,  a.shopname	,	a.x_channel	,	
a.level3	,	null	old_level3	,
a.level4	,	null	old_level4	,
a.facevalue	,	0	old_facevalue	,
a.level3_order	,	a.description	
from  test_db.Base_Table_Sep_onwards a 
--left outer join  test_db.Base_Table_Sep_onwards b on a.orderid = b.orderid and a.HW_Flag = b.HW_Flag      
left outer join (select orderid, group_concat(distinct level3) as level3 from (select a.* from 
(select a.level3 , a.orderid from test_db.Base_Table_Sep_onwards a where a.level3 in ('Service','Accessories','Device','Other')) a ) b 
group by orderid) agg on a.orderid = agg.orderid
where a.level3 <> 'Exclude' 
and a.ordertype = 'Provide';

-- ***************************************************************************************
-- **************************** - Deriveid Logic for Report - ****************************
-- ***************************************************************************************

-- **************************** - Level 1 logic ****************************

--made it into one table 
--  ******************* Device only transactions  *******************
Drop table test_db.Base_Table_Sep_onwards_Pre;

Create table test_db.Base_Table_Sep_onwards_Pre as
select --orderid ,ordertype,productname ,  facevalue , old_product_name , old_facevalue,old_serviceenddate,level3,
datediff(old_serviceenddate,transactiondate) daysdiff,
-- upgrade scenarios
case when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
     when ordertype <> 'Provide' and old_product_name is not null and  (datediff(old_serviceenddate,transactiondate) > 90 
     or datediff(old_serviceenddate,transactiondate) < -90) then 'Upgrade'
--when nvl(facevalue,0)- nvl(old_facevalue,0) < 0 and (productname is not null and level3 = 'Device')  then 'Upgrade'
-- downgrade scenarios
--when nvl(facevalue,0)- nvl(old_facevalue,0) < 0 and (productname is     null and level3 = 'Device')  then 'Downgrade'
when ordertype <> 'Provide' and old_product_name is null     then 'Upgrade'
when ordertype =  'Provide' and old_product_name is not null then 'Provide with old device to be investigated'
when ordertype =  'Provide' and old_product_name is null then 'New'
else 'check' end Level1, *
from test_db.Base_Table_Delete_Sep_onwards where level3 = 'Device' 
--- ******************* Accessories only  *******************
union all
select --orderid ,ordertype,productname ,  facevalue , old_product_name , old_facevalue,old_serviceenddate,level3,
datediff(old_serviceenddate,transactiondate) daysdiff,
-- upgrade scenarios
case when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
     when ordertype <> 'Provide' and old_product_name is not null and  (datediff(old_serviceenddate,transactiondate) > 90 
     or datediff(old_serviceenddate,transactiondate) < -90) then 'Upgrade'
when ordertype <> 'Provide' and old_product_name is null     then 'Upgrade'
when ordertype =  'Provide' and old_product_name is not null then 'Provide with old acc to be investigated'
when ordertype =  'Provide' and old_product_name is     null then 'New'
else 'check' end xGrade, *
from test_db.Base_Table_Delete_Sep_onwards where level3 = 'Accessories'  
--  ******************* other than devices and acc transactions  *******************
union all
select datediff(old_serviceenddate,transactiondate) daysdiff,
-- upgrade scenarios
case --when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
     --when ordertype <> 'Provide' and old_product_name is not null and  (datediff(old_serviceenddate,transactiondate) > 90 or datediff(old_serviceenddate,transactiondate) < -90) then 'Upgrade'
    when lower(product) like '%temp%' then 'Termination Request'
    when lower(old_product_name) like '%temp%' then 'Retention'
    when ordertype = 'Migration' then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) < 0  and serviceenddate is not null then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) < 0 then 'Downgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) > 0 then 'Upgrade'
    when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) = 0 and serviceenddate is not null then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) = 0 then 'Same face value'
    when ordertype = 'Provide' then 'New' else 'check' end xGrade, *
from test_db.Base_Table_Delete_Sep_onwards where level3 = 'Service'  
and orderid not in (select distinct orderid from test_db.Base_Table_Delete_Sep_onwards where level3  in ('Accessories','Device','Other'))
--  ******************* other procuts (i.e. shared sims)  *******************
union all
select datediff(old_serviceenddate,transactiondate) daysdiff,
-- upgrade scenarios
case when lower(product) like '%temp%' then 'Termination Request'
    when lower(old_product_name) like '%temp%' then 'Retention'
    when ordertype = 'Migration' then 'Upgrade Migration'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) < 0  and serviceenddate is not null then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) < 0 then 'Downgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) > 0 then 'Upgrade'
    when ordertype <> 'Provide' and old_product_name is not null and  datediff(old_serviceenddate,transactiondate) between -90 and 90 then 'Renewal' 
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) = 0 and serviceenddate is not null then 'Upgrade'
    when ordertype <> 'Provide' and nvl(facevalue,0)- nvl(old_facevalue,0) = 0 then 'Same face value'
    when ordertype = 'Provide' then 'New'
else 'check' end xGrade, *
from test_db.Base_Table_Delete_Sep_onwards where level3 = 'Other' 
and orderid not in (select distinct orderid from test_db.Base_Table_Delete_Sep_onwards where level3  in ('Accessories','Device','Service'));


------ combining back all sub-tables

Drop table test_db.Base_Table_Sep_onwards_RPT;

Create table test_db.Base_Table_Sep_onwards_RPT AS
select distinct b.Level1 ,
case when level4 = 'ChildSim' then 'Child SIM'
     when level1 = 'Upgrade' and ordertype= 'Migration' and lower(product) not like '%prepaid%' then 'Pre2Post' 
     when level1 = 'Downgrade' and ordertype= 'Migration' and lower(product) like '%prepaid%' then 'Pre2Post' 
     when level1 = 'Upgrade' and nvl(facevalue,0)- nvl(old_facevalue,0) > 0 and serviceenddate is null then 'Post2Post'
     when serviceenddate is not null then 'Contractual'
     when serviceenddate is null and level3_category_case <> 'Service'  then 'Contractual'
     when serviceenddate is null then 'SIM only'  end Level2,
     case when x_channel = "eCommerce" then "E-Shop" when x_channel = "mapp" then "App" else nvl(a.shopname,'Outbound_NVL') end Shop_CRM ,
     a.* , to_date(transactiondate) as SalesDate , hour(transactiondate) as SalesHour 
 , pos_tr.agentid Agent_POS, pos_tr.shop Shop_POS , pos_tr.agent_firstname Agent_Name_POS
 , pos_subid.agentid Agent_POS_SubID , pos_subid.shop Shop_POS_SubID 
, dealer_name Dealer
, pos_subid.transaction_date POS_Timestamp
from test_db.Base_Table_Delete_Sep_onwards a 
left outer join -- level 1 tagging
(select distinct orderid , level1 from test_db.Base_Table_Sep_onwards_Pre) b on a.orderid = b.orderid
 left outer join --- POS CRM Trigger (proxy for below table)
bdl_analytics.triggers_posorderdetails_vw pos on pos.crm_order = a.orderid
left outer join  --- POS trigger join based on Journal ID
bdl_analytics.triggers_grosssales_vw pos_tr on pos.journal_id = pos_tr.journal_id  
left outer join --- POS join based on SubscriberID transaction within 10 hours
bdl_analytics.triggers_grosssales_vw pos_subid on a.subscriberid = pos_subid.subscriberid
and  abs((cast(pos_subid.transaction_date as bigint) - cast(from_utc_timestamp(a.transactiondate,'Asia/Bahrain') as bigint))/60) < 600
left outer join --- MPos delaer details
(SELECT order_num ,Attrib_45 dealer_name FROM  bdl_raw.crm_s_order_1 a , bdl_raw.crm_s_order_x b 
where a.row_id = b.row_id and Attrib_45 is NOT NULL and  x_sub_status = 'Complete') dealer on dealer.order_num = a.orderid;

---- Main table

Drop   table test_db.Base_Table_Sep_onwards_RPT_Cash;

Create table test_db.Base_Table_Sep_onwards_RPT_Cash AS
select a.* , 
---- shop name 
case when username is null and Shop_POS is null then login 
     when shop_crm in ('E-Shop','App') then shop_crm else isnull(Shop_POS,isnull(Shop_POS_SubID,shop_crm)) end ShopNameCombined
--- enrich with SubDim
, b.subscribertypename from
(select * from test_db.Base_Table_Sep_onwards_RPT
union all
---- POS only (shows everything) -> delta is cash sales or zero price sales
--- Cash only
SELECT 'Cash' Level1,  articlegroup Level2,  '' shop_crm , '' level3_category_case  ,   cash_day transactiondate, subscriberid, '' customername,
'' linecategory , msisdn, journal_id orderid, '' contractstartdate, articlename Product, '' old_product_name,  cast(item_total_amount as INT) netprice , 0 old_netprice, '' ordertype
, '' actioncd , '' serviceenddate , transaction_amount duration , '' servicestartdate, '' old_serviceenddate ,'' login , '' username , '' shopname , '' x_channel, '' level3 , '' old_level3
 ,'' level4, '' old_level4 , 0 facevalue, 0 old_facevalue , 0 level3_order , '' description , to_date(cash_day) salesdate , hour(cash_day) SalesHour
 , agentid Agent_POS,  shop Shop_POS, agent_firstname Agent_Name_POS  , '' pos_agent_subid	, '' Shop_POS_SubID , '' dealer   , '' pos_timestamp			
FROM bdl_analytics.triggers_grosssales_vw 
where articlegroup in ('ETOPUP','Recharge Cards','Accessories') and 
to_date(transaction_date) >= '2019-08-31' --and to_date(transaction_date) < '2019-12-01'
and concat(nvl(articleno,'x'),nvl(Journal_id,'x')) not in 
(SELECT concat(nvl(articleno,'x'),nvl(Journal_id,'x'))  FROM bdl_analytics.triggers_posorderdetails_vw
where  to_date(order_completion_date) >= '2019-08-31' 
)) a 
left outer join bdl_rpt.powerbidimsubscriber b on a.subscriberid = b.subscriberid  ;

--------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------- END ----------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------


>>>>>>> 291683003e971e748fa5a0f49acfff3e081edc64

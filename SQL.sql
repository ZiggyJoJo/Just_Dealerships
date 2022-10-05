ALTER TABLE `owned_vehicles`
	ADD `financed` tinyint(1) NOT NULL DEFAULT '0',
	ADD `weeklypayment` int(11) DEFAULT NULL,
	ADD `rempayments` int(11) DEFAULT NULL,
	ADD `nextpayment` int(11) DEFAULT NULL,
	ADD `paymentsoverdue` tinyint(1) NOT NULL DEFAULT '0';
;

CREATE TABLE `repoed_vehicles` (
  `owner` varchar(50) NOT NULL,
  `plate` varchar(12) NOT NULL,
  `vehicle` longtext NOT NULL,
  `type` varchar(20) NOT NULL DEFAULT 'car',
  `job` varchar(20) DEFAULT 'civ',
  `weeklypayment` int(11),
  `rempayments` int(11),
  `paymentsoverdue` tinyint(1),

  PRIMARY KEY (`plate`)
);

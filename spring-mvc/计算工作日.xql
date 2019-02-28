DROP FUNCTION IF EXISTS `workdaynum`;
DELIMITER $$
CREATE FUNCTION `workdaynum`(`datefrom` DATE,`dateto` DATE) 
RETURNS INT(20) NO SQL
BEGIN
	DECLARE days INT DEFAULT 1;
	IF (datefrom > dateto  OR YEAR(datefrom) != YEAR(dateto)) THEN
	   RETURN -1;
	END IF;
	
	SET days = 
	   CASE 
	   WHEN WEEK(dateto)-WEEK(datefrom) = 0 THEN 
	        DAYOFWEEK(dateto) - DAYOFWEEK(datefrom) + 1
		  - CASE 
		    WHEN (DAYOFWEEK(datefrom) > 1 AND DAYOFWEEK(dateto) < 7) THEN 0
		    WHEN (DAYOFWEEK(datefrom) = 1 AND DAYOFWEEK(dateto) =7) THEN 2
		    ELSE 1
		    END
	   ELSE (WEEK(dateto)-WEEK(datefrom)-1) * 5
	      + CASE 
		    WHEN DAYOFWEEK(datefrom) = 1 THEN 5
			WHEN DAYOFWEEK(datefrom) = 7 THEN 0
		    ELSE 7 - DAYOFWEEK(datefrom)
			END
		  + CASE 
		    WHEN DAYOFWEEK(dateto) = 1 THEN 0
			WHEN DAYOFWEEK(dateto) = 7 THEN 5
			ELSE DAYOFWEEK(dateto) - 1
			END
	   END;
			 
	   RETURN days;
END$$
DELIMITER ;


SELECT * FROM xl_privete_holiday ;

SELECT * FROM xl_manager;

SELECT ph.* FROM xl_xnxq xnxq 
JOIN xl_manager manager ON xnxq.`id` = manager.`xnxq_id`
JOIN xl_privete_holiday ph ON ph.`xl_manager_id` = manager.`id`
 WHERE xnxq.xn = '2018-2019' AND xnxq.xq = 1 AND ph.`state` > 0;
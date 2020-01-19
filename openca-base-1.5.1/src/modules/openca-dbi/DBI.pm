## OpenCA::DBI
##
## Written by Michael Bell for the OpenCA project 2000
## Copyright (C) 2000-2004 The OpenCA Project
## GNU public license
##
## Code parts from OpenCA::DB are under the following license
## (copyright statement from OpenCA::DB v0.8.7a
##
## Copyright (C) 1998-1999 Massimiliano Pala (madwolf@openca.org)
## All rights reserved.
##
## This library is free for commercial and non-commercial use as long as
## the following conditions are aheared to.  The following conditions
## apply to all code found in this distribution, be it the RC4, RSA,
## lhash, DES, etc., code; not just the SSL code.  The documentation
## included with this distribution is covered by the same copyright terms
## 
## // Copyright remains Massimiliano Pala's, and as such any Copyright notices
## in the code are not to be removed.
## If this package is used in a product, Massimiliano Pala should be given
## attribution as the author of the parts of the library used.
## This can be in the form of a textual message at program startup or
## in documentation (online or textual) provided with the package.
## 
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions
## are met:
## 1. Redistributions of source code must retain the copyright
##    notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in the
##    documentation and/or other materials provided with the distribution.
## 3. All advertising materials mentioning features or use of this software
##    must display the following acknowledgement:
## //   "This product includes OpenCA software written by Massimiliano Pala
## //    (madwolf@openca.org) and the OpenCA Group (www.openca.org)"
## 4. If you include any Windows specific code (or a derivative thereof) from 
##    some directory (application code) you must include an acknowledgement:
##    "This product includes OpenCA software (www.openca.org)"
## 
## THIS SOFTWARE IS PROVIDED BY OPENCA DEVELOPERS ``AS IS'' AND
## ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
## FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
## DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
## OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
## HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
## LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
## OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
## SUCH DAMAGE.
## 
## The licence and distribution terms for any publically available version or
## derivative of this code cannot be changed.  i.e. this code cannot simply be
## copied and put under another distribution licence
## [including the GNU Public Licence.]
##
## end of license of OpenCA::DB v0.8.7a
##

## special thanks
##
## MySQL:	Julio Sanchez Fernandez <jsanchez@users.sf.net>
## Oracle:	balamood@vt.edu (if somebody knows the fullname I add it
##
## please write a note to us if one of the addresses is wrong

use strict;
use utf8;

package OpenCA::DBI;

our ($errno, $errval);
our ($lastUpdate);

## We must store/retrieve CRLs,CERTs,REQs objects:
## proper instances of object management classes are
## needed.
## see http://www.informatik.hu-berlin.de/~mbell/OpenCA/OpenCA_DBI/OpenCA_DBI.html
## for more information about the datastructure

## The locale category LC_MESSAGES is not exported by the POSIX
## module on older Perl versions.
use Locale::Messages qw (LC_MESSAGES);

use POSIX ('setlocale');

## Set the locale according to our environment.
setlocale (LC_MESSAGES, '');

use OpenCA::REQ;
use OpenCA::X509;
use OpenCA::CRL;
use OpenCA::OpenSSL;
use OpenCA::Tools;
use DBI;

## define the SQL_* values.
use DBI qw(:sql_types);

## the other use directions depends from the used databases

## $Revision: 1.53 $

# code contributed by Andreas Fitzner
($OpenCA::DBI::VERSION = '$Revision: 1.53 $' )=~ s/(?:^.*: (\d+))|(?:\s+\$$)/defined $1?"2\.1":""/eg; 

##################
## DB Org-stuff ##
##################

############################################################################
##  PLEASE read carefully the following conventions before you            ##
##  edit something of the database code                                   ##
############################################################################
##  1.  do not use plural at sometime because you can come into trouble   ##
##      with types                                                        ##
##  2.  please write all types and all names small - this is not good     ##
##      sql-style but sybase ase and ibm db2 for example has no problems  ##
##      with this (they made it big ;-) ). PostgreSQL has with the        ##
##      standard configuration (tested on debian 2.2 i386) really big     ##
##      trouble with names of tables and variables in big letters because ##
##      it tries to convert it to small letters but it does not work      ##
##      correctly (I think because it reports errors of mdopen that the   ##
##      lowercase forget the filename).                                   ##
############################################################################

$OpenCA::DBI::SQL = {
     TABLE => { 
                REQUEST        => "request",
                CERTIFICATE    => "certificate",
                CA_CERTIFICATE => "ca_certificate",
                CRR            => "crr",
                CRL            => "crl",
		USER	      => "user",
		USER_DATA      => "user_data",
		MESSAGES	      => "messages",
                },
      ## I use here several duplicate array
      ## somewhere I have to stop the complexity ...
      VARIABLE => {
                DATE                  => ["submit_date",          "TEXT"],
                SUBMIT_DATE           => ["submit_date",          "TEXT"],
                FORMAT                => ["format",        "TEXT"],
                DATA                  => ["data",          "LONGTEXT"],
                SERIAL                => ["serial",        "BIGINT"],
                ROWID	              => ["rowid",         "AUTO_ID"],
                KEY                   => ["mykey",         "TEXT_KEY"],
                CERTIFICATE_SERIAL    => ["cert_key",      "DECIMAL"],

                # same like certificate_serial but for CRR
                REVOKE_CERTIFICATE_SERIAL    => ["cert_key",      "DECIMAL"],
                CA_CERTIFICATE_SERIAL => ["ca_cert_key",   "TEXT_KEY"],
                REQUEST_SERIAL        => ["req_key",       "BIGINT"],
                CSR_SERIAL            => ["req_key",       "BIGINT"],
                CRR_SERIAL            => ["crr_key",       "BIGINT"],
                APPROVED_AFTER        => ["approved_after", "BIGINT"],
                DELETED_AFTER         => ["deleted_after", "BIGINT"],
                ARCHIVED_AFTER        => ["archivied_after", "BIGINT"],
		#CRL_SERIAL           => ["crl_key",       "TEXT_KEY"],
                CRL_SERIAL            => ["crl_key",       "BIGINT"],
                LOG_SERIAL            => ["action_number", "BIGINT"],
                SIGNATURE_SERIAL      => ["action_number", "BIGINT"],
                # end of redefined variables
                                  
		# Order By
                CERTIFICATE_ORDERBY    		=> ["rowid"],
                REVOKE_CERTIFICATE_ORDERBY 	=> ["rowid"],
                CA_CERTIFICATE_ORDERBY 		=> ["rowid"],
                REQUEST_ORDERBY       		=> ["rowid"],
                CSR_ORDERBY            		=> ["rowid"],
                CRR_ORDERBY            		=> ["rowid"],
                CRL_ORDERBY            		=> ["rowid"],
                USER_ORDERBY           		=> ["rowid"],
                LOG_ORDERBY            		=> ["action_number"],
				  
                # for searching
                DN                => ["dn",            "TEXT"],
                # same like dn but for CRRs
                REVOKE_CERTIFICATE_DN => ["dn",        "TEXT"],
                CN                => ["cn",            "TEXT"],
                EMAIL             => ["email",         "TEXT"],
                RA                => ["ra",            "TEXT"],
                RAO               => ["rao",           "TEXT"],
                OPERATOR          => ["rao",           "TEXT"],
                LAST_UPDATE       => ["last_update",   "BIGINT"],
                NEXT_UPDATE       => ["next_update",   "BIGINT"],
                DATATYPE          => ["datatype",      "TEXT"],
                ROLE              => ["role",          "TEXT"],
                PUBKEY            => ["public_key",    "TEXT"],
                NOTAFTER          => ["notafter",      "BIGINT"],
                NOTBEFORE         => ["notbefore",      "BIGINT"],
                SUSPENDED_AFTER   => ["suspended_after",    "BIGINT"],
                REVOKED_AFTER     => ["revoked_after",      "BIGINT"],
                INVALIDITY_REASON => ["invalidity_reason",  "TEXT"],
                OWNER			  => ["owner",  "OWNER"],
				LAST_ACTIVITY	  => ["last_activity", "BIGINT"],
                SCEP_TID          => ["scep_tid",      "TEXT"],
                LOA               => ["loa",           "TEXT"],
                                  
                # logging and integrity support
                DATATYPE        => ["datatype",      "TEXT"],
                STATUS          => ["status",        "TEXT"],
                REASON          => ["reason",        "TEXT"],
                ACTION_NUMBER   => ["action_number", "BIGINT"],
                MODULETYPE      => ["moduletype",    "TEXT"],
                MODULE          => ["module",        "TEXT"],
                LOG_SUBMIT_DATE => ["log_submit_date",   "TEXT"],
                LOG_DO_DATE     => ["log_do_date",   "TEXT"],

		# user managing support
		USER_ID		=> ["user_id", "USER_ID"],
		EXT_USER_ID	=> ["user_id", "EXT_USER_ID"],
		SECRET		=> ["secret", "TEXT"],
		DATA_SOURCE	=> ["data_source", "TEXT_KEY"],
		EXTERN_ID	=> ["extern_id", "TEXT_KEY"],
		DATA_NAME	=> ["data_name", "TEXT_KEY"],
		DATA_VALUE	=> ["data_value", "TEXT"],

		# messages
		SUBJECT		=> ["subject", "TEXT_KEY" ],
		FROM		=> ["sender", "EXT_USER_ID" ],
		TO		=> [ "receiver", "EXT_USER_ID" ],
		HEADER		=> [ "header", "TEXT" ],
                }
	};

## second call to $OpenCA::DBI::SQL because I use content of this variable
$OpenCA::DBI::SQL->{TABLE_STRUCTURE} = 
  {
   REQUEST => [
               "REQUEST_SERIAL",
               "FORMAT",
               "DATA",
               "DN",
               "CN",
               "EMAIL",
               "RA",
               "OPERATOR",
               "STATUS",
               "ROLE",
               ## should be part of the header itself
               ## "HEADER_SIGNATURE",
               "PUBKEY",
               "SCEP_TID",
               "LOA",
	       "NOTBEFORE",
	       "NOTAFTER",
	       "APPROVED_AFTER",
	       "DELETED_AFTER",
	       "ARCHIVED_AFTER",
	       "CA_CERTIFICATE_SERIAL",
	       "OWNER",
	       "ROWID",
              ],
   CERTIFICATE => [
                   "CERTIFICATE_SERIAL",
                   "FORMAT",
                   "DATA",
                   "DN",
                   "CN",
                   "EMAIL",
                   "STATUS",
                   "ROLE",
                   "PUBKEY",
                   "NOTAFTER",
                   "NOTBEFORE",
                   "CSR_SERIAL",
                   "LOA",
		   "SUSPENDED_AFTER",
		   "REVOKED_AFTER",
		   "INVALIDITY_REASON",
	       	   "OWNER",
	   	   "ROWID",
                  ],
   CA_CERTIFICATE => [
                      ## real serial senseless because at every time zero
                      "CA_CERTIFICATE_SERIAL",
                      "FORMAT",
                      "DATA",
                      "DN",
                      "CN",
                      "EMAIL",
                      "STATUS",
                      "PUBKEY",
                      "NOTAFTER",
                      "NOTBEFORE",
		      "SUSPENDED_AFTER",
		      "REVOKED_AFTER",
		      "INVALIDITY_REASON",
	   	      "ROWID",
                     ],
   CRR => [
           "CRR_SERIAL",
           "REVOKE_CERTIFICATE_SERIAL",
           "SUBMIT_DATE",
           "FORMAT",
           "DATA",
           "REVOKE_CERTIFICATE_DN",
           "CN",
           "EMAIL",
           "RA",
           "OPERATOR",
           "STATUS",
           "REASON",
	   "NOTBEFORE",
	   "NOTAFTER",
	   "APPROVED_AFTER",
	   "DELETED_AFTER",
	   "ARCHIVED_AFTER",
           "LOA",
	   "OWNER",
	   "ROWID",
           ## should be part of the header itself
           ## "HEADER_SIGNATURE"
          ],
   CRL => [
           "CRL_SERIAL",
           "STATUS",
           "FORMAT",
           "DATA",
           "LAST_UPDATE",
           "NEXT_UPDATE",
	   "ROWID",
          ],
   USER => [
	   "ROWID",
	   "USER_ID",
	   "DATA_SOURCE",
	   "SECRET",
	   "NOTAFTER",
	   "NOTBEFORE",
	   "STATUS",
	   "EXTERN_ID",
	   "SUSPENDED_AFTER",
	   "REVOKED_AFTER",
	   "LAST_ACTIVITY",
	   "INVALIDITY_REASON",
	   ],
   USER_DATA => [
	   "ROWID",
	   "USER_ID",
	   "DATA_NAME",
	   "DATA_VALUE",
	   "DATA_SOURCE",
	   ],
   MESSAGES => [
	   "ROWID",
	   "FROM",
	   "TO",
	   "SUBJECT",
	   "NOTBEFORE",
	   "HEADER",
	   "DATA",
	   "STATUS",
	   ],
  };

$OpenCA::DBI::SQL->{FOREIGN_KEYS} = {
	USER_DATA => { 
			USER_ID => ["USER", "USER_ID"] 
		     },
	MESSAGES  => { 
			FROM => [ "USER", "USER_ID" ],
		 	TO   => [ "USER", "USER_ID" ],
		     },
};

$OpenCA::DBI::STATUS = {
			EXIST       => 1,
			VALID       => 2,
			RENEW       => 3,
			UPDATED     => 4,
			PENDING     => 5,
			APPROVED    => 6,
			SUSPENDED   => 7,
			REVOKED     => 8,
			DELETED     => 9,
			ARCHIVED    => 10,
			EXPIRED     => 11,
			NONEXISTENT => 12,
			ANY         => 13,
			NEW         => 14,
			SIGNED      => 15,
			## TEMP STATUSES
			TEMPNEW			=> 16,
			TEMPPENDING		=> 17,
			TEMPAPPROVED	=> 18,
	};

#########################
## end of DB Org-stuff ##
#########################

#################
## error-codes ##
#################

$OpenCA::DBI::ERROR = {
  
  SUCCESS            => 0,
  DO_NOT_COMMIT      => 11111, # protects the database from commiting if the modul crashs
  UNEXPECTED_ERROR   => 88888,
  ATTACK             => 16666,
                       
  # unspecific errors
  WRONG_DATATYPE               => 10001,
  NO_OBJECT                    => 10002,
  GETBASETYPE_FAILED           => 10003,
  UPDATE_WITHOUT_KEY           => 10004,
  UPDATE_WITHOUT_KEY           => 10005,
  ENTRY_EXIST                  => 10006,
  ENTRY_NOT_EXIST              => 10007,
  UNSUPPORTED_SEARCH_ATTRIBUTE => 10008,
  DB_TYPE_UNKNOWN              => 10009,
  SIGNING_LOG_FAILED           => 10010,
  ITEM_NOT_UNIQUE              => 10011,
  FALSE_MODE                   => 10012,
  FALSE_FAILSAFE               => 10013,
  FALSE_SECOND_CHANCE          => 10014,
  MISSING_PRIMARY_DATABASE     => 10015,
  MISSING_BACKUP_DATABASE      => 10016,
  MISSING_BACKEND              => 10017,
  MISSING_TOOLS                => 10018,
  AUTOCOMMIT                   => 10019,

  CERTIFICATE_TABLE_EXIST      => 10020,
  CA_CERTIFICATE_TABLE_EXIST   => 10021,
  CRR_TABLE_EXIST              => 10022,
  CRL_TABLE_EXIST              => 10023,
  LOG_TABLE_EXIST              => 10024,
  SIGNATURE_TABLE_EXIST        => 10025,
  SEQUENCE_TABLE_EXIST         => 10026,
  RBAC_TABLE_EXIST             => 10027,
  REQUEST_TABLE_EXIST          => 10028,
  
  CANNOT_REMOVE_CA_CERTIFICATE => 10030,
  CANNOT_REMOVE_CRR            => 10031,
  CANNOT_REMOVE_CRL            => 10032,
  CANNOT_REMOVE_LOG            => 10033,
  CANNOT_REMOVE_SIGNATURE      => 10034,
  CANNOT_REMOVE_SEQUENCE       => 10035,
  CANNOT_REMOVE_RBAC           => 10036,
  CANNOT_REMOVE_REQUEST        => 10037,
  CANNOT_REMOVE_CERTIFICATE    => 10038,
  
  CANNOT_CREATE_CA_CERTIFICATE => 10040,
  CANNOT_CREATE_CRR            => 10041,
  CANNOT_CREATE_CRL            => 10042,
  CANNOT_CREATE_LOG            => 10043,
  CANNOT_CREATE_SIGNATURE      => 10044,
  CANNOT_CREATE_SEQUENCE       => 10045,
  CANNOT_CREATE_RBAC           => 10046,
  CANNOT_CREATE_REQUEST        => 10047,
  CANNOT_CREATE_CERTIFICATE    => 10048,
 
  CANNOT_INIT_SEQUENCE         => 10050,

  CANNOT_CREATE_OBJECT         => 10060,
  MISSING_ARG_TABLE            => 10061,
  MISSING_ARG_SERIAL           => 10062,
  MISSING_ARG_DATATYPE         => 10063,
  UNSUPPORTED_OBJECT           => 10064,
  ILLEGAL_STATUS               => 10065,
  ILLEGAL_DATE                 => 10067,
  ILLEGAL_ARGUMENT             => 10068,
  MISSING_DATABASE_PARAMETERS  => 10070,
  MISSING_GETTEXT              => 10071,
  MISSING_DATABASE_TYPE        => 10072,
  MISSING_DATABASE_NAME        => 10073,
  MISSING_DATABASE_USER        => 10074,
  MISSING_DATABASE_PASSWD      => 10075,

  # DB-errors
  # using bitwise-or for DIAGNOSTICS so (ERROR+20000) 
  # & ERROR_MASK -> yes/no
  
  CONNECT_FAILED        => 20001,
  SECOND_CONNECT_FAILED => 20002,
  NO_BACKUP             => 20004,
 
  PREPARE_FAILED        => 20008,
  EXECUTE_FAILED        => 20016,
  
  SELECT_FAILED         => 20032,
  UPDATE_FAILED         => 20064,
  INSERT_FAILED         => 20128,
  DELETE_FAILED         => 20256,
  COMMIT_FAILED         => 20512,
  ROLLBACK_FAILED       => 21024,
  DISCONNECT_FAILED     => 22048,
  SEQUENCE_GENERATOR_FAILED => 24096,

                      };
  
$OpenCA::DBI::MESSAGE = {
  
  0     => "Success",
  88888 => "Unexpected Error",
  16666 => "Possible Attack",
                       
  # unspecific errors
  10001 => "WRONG_DATATYPE",
  10002 => "NO_OBJECT",
  10003 => "GETBASETYPE_FAILED",
  10004 => "UPDATE_WITHOUT_KEY",
  10006 => "ENTRY_EXIST",
  10007 => "ENTRY_NOT_EXIST",
  10008 => "UNSUPPORTED_SEARCH_ATTRIBUTE",
  10009 => "DB_TYPE_UNKNOWN",
  10010 => "SIGNING_LOG_FAILED",
  10011 => "ITEM_NOT_UNIQUE",
  10012 => "FALSE_MODE - normally this means, that you are not using ".
           "secure or standard as the accessmode.",
  10013 => "FALSE_FAILSAFE - failsafe \"on|off\".",
  10014 => "FALSE_SECOND_CHANCE - second_chance \"yes|no\"",
  10015 => "MISSING_PRIMARY_DATABASE",
  10016 => "MISSING_BACKUP_DATABASE",
  10017 => "MISSING_BACKEND",
  10018 => "MISSING_TOOLS",
  10019 => "AUTOCOMMMIT is on.",
  
  10020 => "The table certificate already exists.",
  10021 => "The table ca_certificate already exists.",
  10022 => "The table crr already exists.",
  10023 => "The table crl already exists.",
  10024 => "The table log already exists.",
  10025 => "The table signature already exists.",
  10026 => "The sequence generator already exists.",
  10027 => "The table rbac already exists.",
  10028 => "The table request already exists.",
  
  10030 => "Cannot drop the table ca_certificate.",
  10031 => "Cannot drop the table crr.",
  10032 => "Cannot drop the table crl.",
  10033 => "Cannot drop the table log.",
  10034 => "Cannot drop the table signature.",
  10035 => "Cannot drop the sequence generator.",
  10036 => "Cannot drop the table rbac.",
  10037 => "Cannot drop the table request.",
  10038 => "Cannot drop the table certificate.",
  
  10040 => "Cannot create the table ca_certificate.",
  10041 => "Cannot create the table crr.",
  10042 => "Cannot create the table crl.",
  10043 => "Cannot create the table log.",
  10044 => "Cannot create the table signature.",
  10045 => "Cannot create the sequence generator.",
  10046 => "Cannot create the table rbac.",
  10047 => "Cannot create the table request.",
  10048 => "Cannot create the table certificate.",

  10050 => "Cannot init sequence generator.",  

  10060 => "CANNOT_CREATE_OBJECT",
  10061 => "MISSING_ARG_TABLE",
  10062 => "MISSING_ARG_SERIAL",
  10063 => "MISSING_ARG_DATATYPE",
  10064 => "UNSUPPORTED_OBJECT",
  10065 => "ILLEGAL_STATUS",
  10067 => "ILLEGAL_DATE",
  10068 => "There is an illegal or unsupported argument.",
  10070 => "Missing database parameters (type, name, user or passphrase). Does the passphrase be empty?",
  10071 => "The translation function is missing.",
  10072 => "The database type is missing.",
  10073 => "The database name is missing.",
  10074 => "The database user is missing.",
  10075 => "The database passphrase is missing. There must be a database passphrase.",

  11111 => "Do not commit if the database or the module itself fails.",
  # DB-errors
  # using bitwise-or for DIAGNOSTICS so (ERROR+20000) 
  # & ERROR_MASK -> yes/no
  
  20001 => "CONNECT_FAILED",
  20002 => "SECOND_CONNECT_FAILED",
  20004 => "NO_BACKUP",
 
  20008 => "PREPARE_FAILED",
  20016 => "EXECUTE_FAILED",
  
  20032 => "SELECT_FAILED",
  20064 => "UPDATE_FAILED",
  20128 => "INSERT_FAILED",
  20256 => "DELETE_FAILED",
  20512 => "COMMIT_FAILED",
  21024 => "ROLLBACK_FAILED",
  22048 => "DISCONNECT_FAILED",
  24096 => "SEQUENCE_GENERATOR_FAILED",

                      };
  
## these vars are used to handle crashes during new
$OpenCA::DBI::ERRNO  = $OpenCA::DBI::ERROR->{SUCCESS};

#######################
## end of errorcodes ##
#######################  

################
## modulecodes ##
################

$OpenCA::DBI::MODULETYPE = {
                           UNKNOWN    => 0,
                           CA         => 1,
                           PKIManager => 2,
                           RA         => 3,
                           WebGateway => 4,
                           RAServer   => 5,
                          };
	      
#######################
## end of modulecodes ##
#######################

############################################
## begin of vendordependent databasestuff ##
############################################

## how much spped costs this for 10 databases (compared with 2 databases)?
$OpenCA::DBI::DB = {
                    Pg => {
                           TYPE => {
                                    ## numeric available but not documented
                                    TEXT       => "text",
                                    LONGTEXT   => "text",
                                    TEXT_KEY   => "text",
                                    BIGINT     => "int8",
				    				AUTO_ID    => "BIGSERIAL",
				    				DECIMAL    => "DECIMAL (60, 0)",
				    				USER_ID    => "VARCHAR(255)",
				    				EXT_USER_ID => "VARCHAR(255) NOT NULL",
				    				OWNER      => "VARCHAR(255)",
                                    PRIMARYKEY => "PRIMARY KEY NOT NULL",
                                   },
                           DBI_OPTION => {
                                    RaiseError => 0, 
                                    Taint => 0, 
                                    AutoCommit => 0},
                           			LIMIT => "__QUERY__ LIMIT __MAXITEMS__",
			   						FOREIGN_KEY => "ALTER TABLE __TABLE__ ADD CONSTRAINT __COL__REF__TARGET_COL__ FOREIGN KEY (__COL__) REFERENCES __TARGET_TABLE__(__TARGET_COL__)",
                          },
                    mysql => {
                              TYPE => {
                                       ## numeric available but not documented
                                    TEXT       => "TEXT",
                                    LONGTEXT   => "TEXT",
                                    TEXT_KEY   => "VARCHAR (255)",
                                    BIGINT     => "BIGINT",
								    DECIMAL    => "DECIMAL (60, 0)",
								    USER_ID    => "VARCHAR(255)",
								    AUTO_ID    => "SERIAL",
								    EXT_USER_ID => "VARCHAR(255) NOT NULL",
								    OWNER      => "VARCHAR(255)",
                                    PRIMARYKEY => "NOT NULL PRIMARY KEY",
				    
                                    },
                              DBI_OPTION => {RaiseError => 0,
                                             AutoCommit => 0},
                              # CREATE_TABLE_OPTION => "TYPE=BDB ENGINE=INNODB CHARSET=utf8",
                              CREATE_TABLE_OPTION => "ENGINE=INNODB CHARSET=utf8",
                              LIMIT => "__QUERY__ LIMIT __MAXITEMS__",
			      FOREIGN_KEY => "ALTER TABLE __TABLE__ ADD CONSTRAINT __COL___REF___TARGET_COL__ FOREIGN KEY (__COL__) REFERENCES __TARGET_TABLE__ (__TARGET_COL__)",
                             },
                    DB2 => {
                            TYPE => {
                                    TEXT       => "long varchar",
                                    LONGTEXT   => "long varchar",
                                    ## 255 is the limit for a index key in db2
                                    TEXT_KEY   => "varchar (255)",
                                    BIGINT     => "decimal (31, 0)",
				    DECIMAL    => "DECIMAL (31, 0)",
				    USER_ID    => "VARCHAR(255)",
				    EXT_USER_ID=> "VARCHAR(255) NOT NULL",
				    OWNER      => "VARCHAR(255)",
				    AUTO_ID    => "SERIAL",
                                    PRIMARYKEY => "PRIMARY KEY NOT NULL",
                                    },
                            DBI_OPTION => {
                                           RaiseError => 0, 
                                           Taint => 0, 
                                           AutoCommit => 0},
                            LIMIT => "__QUERY__ FETCH FIRST __MAXITEMS__ ROWS ONLY",
			    FOREIGN_KEY => "ALTER TABLE __TABLE__ ADD CONSTRAINT __COL__REF__TARGET_COL__ FOREIGN KEY (__COL__) REFERENCES __TARGET_TABLE__(__TARGET_COL__)",
                           },
                    Oracle => {
                            TYPE => {
                                    TEXT       => "varchar2 (1999)",
                                    LONGTEXT   => "LONG",
                                    ## 2000 is the limit for varchar in Oracle7
                                    TEXT_KEY   => "varchar2 (1999)",
                                    BIGINT     => "number (38)",
				    DECIMAL    => "DECIMAL (38, 0)",
				    USER_ID    => "VARCHAR2(255)",
				    EXT_USER_ID => "VARCHAR2(255) NOT NULL",
				    OWNER      => "VARCHAR(255)",
				    AUTO_ID    => "DECIMAL(38,0) NOT NULL AUTO INCREMENT",
                                    PRIMARYKEY => "PRIMARY KEY NOT NULL",
                                    },
                            DBI_OPTION => {
                                           RaiseError => 0, 
                                           Taint => 0, 
                                           AutoCommit => 0,
                                           LongReadLen => 32767},
                            LIMIT => "select * from ( __QUERY__ ) where rownum <= __MAXITEMS__",
			     FOREIGN_KEY => "ALTER TABLE __TABLE__ ADD CONSTRAINT __COL__REF__TARGET_COL__ FOREIGN KEY (__COL__) REFERENCES __TARGET_TABLE__(__TARGET_COL__) INITIALLY DEFERRED DEFERRABLE"
                           },
                   };

##########################################
## end of vendordependent databasestuff ##
##########################################

$OpenCA::DBI::beginHeader     = "-----BEGIN HEADER-----";
$OpenCA::DBI::endHeader       = "-----END HEADER-----";
$OpenCA::DBI::beginAttribute  = "-----BEGIN ATTRIBUTE-----";
$OpenCA::DBI::endAttribute    = "-----END ATTRIBUTE-----";

## here a special remark
## OpenCA::DBI uses only PEM and such things like SPKAC ...
## binary data like DER is not storable in textfields

my $params = {
		backend => undef,
		## debugging is off !!!
		DEBUG  => 0,
		DEBUG_STDERR  => 0,
		ERRNO  => 0,
		ERRVAL => "",
	};

sub new {
  
  # no idea what this should do
  
  my $that = shift;
  my $class = ref($that) || $that;
  
  ## my $self  = $params;
  my $self;
  my $help;
  foreach $help (keys %{$params}) {
    $self->{$help} = $params->{$help};
  }                                                                                          
 
  bless $self, $class;

  ## because db uses variablenames etc. I cannot define it in $params :-(

  # ok here I start ;-)

  my $keys = { @_ };

  $self->debug ("new: Starting to init a new OpenCA::DBI");

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  # non-DB-specific

  $self->{DEBUG}          = 1 if ($keys->{DEBUG});
  $self->{DEBUG_STDERR}   = 1 if ($keys->{DEBUG_STDERR});
  $self->{gettext}        = $keys->{GETTEXT};
  $self->{backend}        = $keys->{SHELL};


  $self->debug ("new: checking for backend");

  if (not $self->{backend})
  {
    $self->set_error ( $OpenCA::DBI::ERROR->{MISSING_BACKEND} );
    return undef;
  }

  $self->debug ("new: defining the class parameters");

  # The minimum I need is remote: 
  # type, host, port, name, user, passwd

  $self->{DB_Type}   = $keys->{DB_Type};
  $self->{DB_Host}   = $keys->{DB_Host};
  $self->{DB_Port}   = $keys->{DB_Port};
  $self->{DB_Name}   = $keys->{DB_Name};
  $self->{DB_User}   = $keys->{DB_User};
  $self->{DB_Passwd} = $keys->{DB_Passwd};
  $self->{DB_Namespace} = $keys->{DB_Namespace};

  ## rewrite table names if there is a namespace

  $self->debug ("new: rewrite table spaces if necessary (namespace)");
  if ($keys->{DB_Namespace})
  {
      my $tableprefix = $keys->{DB_Namespace}.".";
      foreach my $table (keys %{$OpenCA::DBI::SQL->{TABLE}})
      {
          $OpenCA::DBI::SQL->{TABLE}->{$table} =
              $tableprefix.$OpenCA::DBI::SQL->{TABLE}->{$table};
      }
  }

  # Check for all neccessary variables to initialize OpenCA:DBI 

  $self->debug ("new: checking the configuration for enough data");

  if ( not $self->{gettext} ) {
    $self->set_error ( $OpenCA::DBI::ERROR->{MISSING_GETTEXT} );
    return undef;
  }

  return $self->set_error ($OpenCA::DBI::ERROR->{MISSING_DATABASE_TYPE})
      if (not $self->{DB_Type});
  return $self->set_error ($OpenCA::DBI::ERROR->{MISSING_DATABASE_USER})
      if (not $self->{DB_User});

  # 2004-10-27 Martin Bartosch <m.bartosch@cynops.de>
  # added special handling for Oracle external authentication
  if ($self->{DB_Type} ne 'Oracle') {
      return $self->set_error ($OpenCA::DBI::ERROR->{MISSING_DATABASE_NAME})
	  if (not $self->{DB_Name});
      return $self->set_error ($OpenCA::DBI::ERROR->{MISSING_DATABASE_PASSWD})
	  if (not $self->{DB_Passwd});
  } else {
      # Oracle does not require a database name if the ORACLE_SID is specified
      # in the environment. 
      # If external authentication is used with Oracle then DB_Name MUST 
      # be empty and ORACLE_SID MUST be set (see DBD::Oracle).
      return $self->set_error ($OpenCA::DBI::ERROR->{MISSING_DATABASE_NAME})
	  unless (($self->{DB_Name} ne '') or ($ENV{ORACLE_SID} ne ''));

      # Oracle allows 'external authentication'. In this case the username
      # is set to '/' and the password is empty.
      return $self->set_error ($OpenCA::DBI::ERROR->{MISSING_DATABASE_PASSWD})
	  unless (($self->{DB_Passwd} ne '') or ($self->{DB_User} eq '/'));
  }

  # The availability of the databases is checked during the operations
  # because I have different accessed databases and perhaps failsafe.
  # I could only stop here if there is no database online but to write
  # here a very big test only for this purpose makes no sense.

  ###########################
  ## vendor dependent part ##
  ###########################

  ## preparing now the database-strings
  ## this is very database dependent
  $self->debug ("new: preparing the database (vendor dependent)");

  ## WARNING I do not include any attributes into the DSN
  ## because I do not know how widely version 1.10 of DBI is used actually
  ## END of WARNING

  $self->{DSN} = "dbi:".$self->{DB_Type}.":";
  if ($self->{DB_Type} eq "Pg") {
    $self->debug ("new: Pg detected");
    $self->{DSN} .= "dbname=".$self->{DB_Name};
    $self->{DSN} .= ";"."host=".$self->{DB_Host} if ($self->{DB_Host});
    $self->{DSN} .= ";"."port=".$self->{DB_Port} if ($self->{DB_Port});
  } elsif ($self->{DB_Type} eq "mysql") {
    $self->debug ("new: mysql detected");
    $self->{DSN} .= "database=".$self->{DB_Name};
    $self->{DSN} .= ";"."host=".$self->{DB_Host} if ($self->{DB_Host});
    $self->{DSN} .= ";"."port=".$self->{DB_Port} if ($self->{DB_Port});
    ## not clean but safe
    $self->{DSN} .= ";mysql_ssl=0";
  } elsif ($self->{DB_Type} =~ /^DB2$/ ) {
    $self->debug ("new: DB2 detected");
    $self->{DSN} .= $self->{DB_Name};
  } elsif ($self->{DB_Type} =~ /^Oracle$/ ) {
    $self->debug ("new: Oracle detected");
    ## you can use tnsname or sidname
    $self->{DSN} .= $self->{DB_Name};
  } else {
   $self->set_error ( $OpenCA::DBI::ERROR->{DB_TYPE_UNKNOWN} );
   return undef;
  }
  $self->debug ("new: DB: ".$self->{DSN});

  ##################################
  ## end of vendor dependent part ##
  ##################################

  $self->debug ("new: OpenCA::DBI should now complete");

  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} ); 
  return $self;
  
}

sub connect 
{
  my $self = shift;

	our ($DEBUG);

  $self->debug ("connect: connecting to database");

  ## dsn etc. defined so lets try
  $self->debug ("connect: try to connect");

	## If there is a previously cached value, let's disconnect first
	if ($self->{DBH})
	{
		$self->disconnect();
		$self->{DBH} = undef;
	}
  $self->{STH} = undef;

	## Now, re-connect
 	$self->{DBH} = DBI->connect_cached ($self->{DSN},
                               $self->{DB_User},
                               $self->{DB_Passwd}, 
                               \%{$OpenCA::DBI::DB->{$self->{DB_Type}}->{DBI_OPTION}});

  if (not defined ($self->{DBH}))
	{
    ## connect failed try again
    $self->debug ("connect: connect failed");
    $self->set_error ( $DBI::err, $DBI::errstr);
    $self->set_error ( $OpenCA::DBI::ERROR->{CONNECT_FAILED} );
    return undef;
  }

  $self->debug ("connect: Checking AutoCommit to be off ...");
  if ($self->{DBH}->{AutoCommit} == 1)
	{
    $self->debug ("connect: AutoCommit is on so I'm aborting ...");
    $self->set_error ( $OpenCA::DBI::ERROR->{AUTOCOMMIT} );
    return undef;
  }
  $self->debug ("connect: AutoCommit is off");

  my $charset = setlocale (LC_MESSAGES);
  if ($charset =~ /[^\.]+\.[^\.]+/)
  {
    ## encoding is set
    if( ($self->{DB_Type} =~ /mysql/i ) and ($charset =~ /utf-8/i ) ) {
	    $charset = 'utf8';
    }

    $self->debug ("connect: Setting characterset if the database support it ...");
    $charset =~ s/^[^\.]+\.//g;
    $self->doQuery (QUERY => "SET NAMES '$charset'");
    $self->debug ("connect: Characterset fixed if possible");
  }

  if ( $self->{DB_Type} =~ /Pg/i ) {
	## We Set the option for Pg Database
	$self->{DBH}->{pg_enable_utf8} = 'true';
  }

  return 1;
}

#############################
## database initialization ##
#############################

sub initDB {
  ## Generate a new db and initialize it allowing the
  ## DB to keep track of the DB status
 
  my $self = shift;
  my $keys = { @_ };
  
  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my $mode   = $keys->{MODE};

  $self->debug ("initDB: Entering sub initDB");
  $self->debug ("initDB: MODE: $mode");

  ## Accepted modes are
  ## NONE
  ## FORCE    to force table creation
  ## DRYRUN   to get SQL commands

  my ($db, $force, $table, $dsn); 
  # force ?
  $force = 0;
  if ( $mode =~ /^FORCE$/i ) {
      $force = 1;
  } elsif ( $mode eq "DRYRUN") {
      $self->{SQL_SCRIPT} = "";
  }
  $self->debug ("initDB: force: $force");
    
  ## For Postgres, we generate a new SCHEMA, to be used with namespace
  ## option (to distinguish between openca's user and pg's user tables)
  if ( $self->{DB_Type} =~ /Pg/i ) {
   	my $query = undef;

	if ( $self->{DB_Namespace} eq "" ) {
		generalError( "Please use option <b>namespace</b> in ".
			"PREFIX/etc/openca/config.xml (required for " .
			"DB Type (" . $self->{DB_Type} . ")" );
	}

	$query = qq{CREATE SCHEMA } . $self->{DB_Namespace};
	if ( not defined $self->doQuery ( QUERY => $query,
                                       BIND_VALUES => undef ) ) {
               	$self->debug_err("upgradeDB: doQuery fail ($query)");
       	};
  }

  foreach $table (keys %{$OpenCA::DBI::SQL->{TABLE}}) {
    $self->debug ("initDB: table: $table");
    # check for existence
    $self->debug ("initDB: dsn: ".$self->{DSN});
    $self->debug ("initDB: the folloing debugging-output is for DB2");
    $self->debug ("initDB: ld_library_path: ".$ENV{LD_LIBRARY_PATH});
    $self->debug ("initDB: path: ".           $ENV{PATH});
    $self->debug ("initDB: libpath".          $ENV{LIBPATH});
    $self->debug ("initDB: classpath".        $ENV{CLASSPATH});
    $self->debug ("initDB: oracle_home".      $ENV{ORACLE_HOME});

    if (defined $self->operateTable (DO=>"exist", TABLE => $table, 
							MODE => $mode )) {
      if ($force or $mode eq "DRYRUN") {
        if (not defined $self->operateTable (DO=>"drop", TABLE => $table, 
							MODE => $mode)) {
          $self->set_error ( $OpenCA::DBI::ERROR->{ "CANNOT_REMOVE_".$table } );
          $self->rollback ();
	  return undef;
	}

      } else {
        $self->set_error ( $OpenCA::DBI::ERROR->{ $table."_TABLE_EXIST" } );
        $self->rollback ();
        return undef;
      }
    }
    $self->debug ("initDB: try to create table");
    # create table
    if (not defined $self->operateTable (DO=>"create", TABLE => $table, MODE => $mode)) {
      $self->set_error ( $OpenCA::DBI::ERROR->{ "CANNOT_CREATE_".$table } );
      $self->rollback ();
      return undef;
    }
    $self->debug ("initDB: table created");
  }

  if (not defined $self->commit ()) {
    $self->rollback ();
    return undef;
  }

  $self->debug ("initDB: initDB successful completed");
  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
  return $self->{SQL_SCRIPT} if ($mode eq "DRYRUN");
  return 1;
}

sub operateTable {
  my $self = shift;
  my $keys = { @_ };
  
  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my $table     = $keys->{TABLE};
  my $operation = $keys->{DO};
 
  $self->debug ("operateTable: Entering sub operateTable");
 
  # the tables
  my (%tables, $dbh, $statement, $create);

  $self->debug ("operateTable: build the create statements");

  ############################
  ## initial tablestructure ##
  ## change carefully !!!   ##
  ############################

  $self->debug_err ("operateTable: table: ($table)".
				$OpenCA::DBI::SQL->{TABLE}->{$table});
  $create = "create table ".$OpenCA::DBI::SQL->{TABLE}->{$table}." (";
  for (my $i=0; 
       $i < scalar (@{$OpenCA::DBI::SQL->{TABLE_STRUCTURE}->{$table}}); 
       $i++) {
    if ($i == 0) {
      $create .= $OpenCA::DBI::SQL->{VARIABLE}->{
                   $OpenCA::DBI::SQL->{TABLE_STRUCTURE}->{$table}[0]
                 }[0]." ".
                 $OpenCA::DBI::DB->{$self->{DB_Type}}->{TYPE}->{
                   $OpenCA::DBI::SQL->{VARIABLE}->{
                     $OpenCA::DBI::SQL->{TABLE_STRUCTURE}->{$table}[0]
                   }[1]
                 };
	if ( $table =~ /CA_CERTIFICATE|CERTIFICATE|CRL|CRR|REQUEST|USER/ ) {
		$create .= " " . 
		   $OpenCA::DBI::DB->{$self->{DB_Type}}->{TYPE}->{PRIMARYKEY};
	};
    } else {
      $create .= ", ".
                 $OpenCA::DBI::SQL->{VARIABLE}->{
                   $OpenCA::DBI::SQL->{TABLE_STRUCTURE}->{$table}[$i]
                 }[0]." ".
                 $OpenCA::DBI::DB->{$self->{DB_Type}}->{TYPE}->{
                   $OpenCA::DBI::SQL->{VARIABLE}->{
                     $OpenCA::DBI::SQL->{TABLE_STRUCTURE}->{$table}[$i]
                   }[1]
                 };
    }
  }
  $create .= ")";
  $create .= " ".$OpenCA::DBI::DB->{$self->{DB_Type}}->{CREATE_TABLE_OPTION}
    if (exists $OpenCA::DBI::DB->{$self->{DB_Type}}->{CREATE_TABLE_OPTION});

  $self->debug ("operateTable: create: $create");

  ############################
  ##      end of            ##
  ## initial tablestructure ##
  ## change carefully !!!   ##
  ############################

  $self->debug ("operateTable: build the statement finally");

  # check table
  my $negator = 0;
  if ($operation eq "create") {
    $statement = $create;
  } elsif ($operation eq "drop") {
    $statement = "drop table ".$OpenCA::DBI::SQL->{TABLE}->{$table};
  } else {
    $statement = "select * from ".$OpenCA::DBI::SQL->{TABLE}->{$table};
  }

  $self->debug_err ("operateTable: statement: $statement");
  ## can happen if operation performs for sequence generator
  if ($statement eq "") {
    $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
    return 1;
  }
  $self->debug ("operateTable: run the statement");

  # attention not for final use because of the central 
  # $OpenCA::DBI::ERROR VARIABLE !!!

  # because of a postgres-bug we must commit all changes here
  if ($self->{DB_Type} =~ /Pg/i) {
      $self->commit();
  }
  if ($keys->{MODE} eq "DRYRUN") {
    	$self->{SQL_SCRIPT} .= $statement.";";
  } else {
	my $ret = $self->doQuery ( QUERY => $statement );
	if ( not defined $ret ) {
		$self->debug ("operateTable: query failed return " .
				"undef (EXCEPT OF NEGATOR)");

		# because of a postgres-bug we must rollback here to 
		# rescue the following operations
      	if ($self->{DB_Type} =~ /Pg/i) {
          	$self->rollback();
      	}

      	if ($negator) {
        	$self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
        	return 1;
      	}
      	return undef;
    }
  }

  $self->debug ("operateTable: query succeeded return 1 (EXCEPT OF NEGATOR)");
  return undef if ($negator);
  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
  return 1;
  
}

## ##################################################################
## Function Name: upgradeDB
## ##################################################################

sub upgradeDB {

	my $self = shift;
	my $query = "";
	my $keys = { @_ };

	my @bind_values = ();
	my @my_tables = ();

	my $mode = "FORCE";

    	if ( $self->{DB_Type} =~ /Pg/i ) {
	   	my $query = undef;

		if ( $self->{DB_Namespace} eq "" ) {
			generalError( "Please use option <b>namespace</b> in ".
				"PREFIX/etc/openca/config.xml (required for " .
				"DB Type (" . $self->{DB_Type} . ")" );
		}

		$query = qq{CREATE SCHEMA } . $self->{DB_Namespace};
		if ( not defined $self->doQuery ( QUERY => $query,
                                        BIND_VALUES => undef ) ) {
                	$self->debug_err("upgradeDB: doQuery fail ($query)");
			$self->rollback();
        	} else {
			$self->commit();
		}
	}

	$query = "alter table certificate alter column " .
		$OpenCA::DBI::SQL->{VARIABLE}->{
                   $OpenCA::DBI::SQL->{TABLE_STRUCTURE}->{CERTIFICATE}[0]
                 }[0]." ".
                 $OpenCA::DBI::DB->{$self->{DB_Type}}->{TYPE}->{
                   $OpenCA::DBI::SQL->{VARIABLE}->{
                     $OpenCA::DBI::SQL->{TABLE_STRUCTURE}->{CERTIFICATE}[0]}
			[1]};


	if ( not defined $self->doQuery ( QUERY => $query,
                                        BIND_VALUES => \@bind_values) ) {
                $self->debug_err("upgradeDB: doQuery failure detected 2");
		$self->rollback();
        } else {
		$self->commit();
	}

    ## Create the new tables
    @my_tables = ( "USER", "USER_DATA", "MESSAGES" );
    foreach my $table ( @my_tables ) {
    	if (defined $self->operateTable (DO=>"exist", TABLE => $table, 
							MODE => $mode)) {
		$self->debug_err ("upgradeDB::Table $table exists, skipping.");
		next;
	};

    	if (not defined $self->operateTable (DO=>"create", TABLE => $table )) {
		$self->debug_err ("upgradeDB::ERROR creating TABLE $table.");
		$self->rollback();
    	}

  	if (not defined $self->commit ()) {
		$self->debug_err ("upgradeDB::Commit failed for $table");
	}
    }

    foreach my $table ( keys %{$OpenCA::DBI::SQL->{FOREIGN_KEYS}} ) {

	## Now add the Foreign Keys
	if ( defined $OpenCA::DBI::SQL->{FOREIGN_KEYS}->{$table} ) {
		my ( $col, $target_col, $target_table );
		my ( %refs );
		my ( $query, $myTable );

		$self->debug_err ( "foreignKey:: Keys to be added for $table");

		%refs = %{$OpenCA::DBI::SQL->{FOREIGN_KEYS}->{$table}};

		foreach my $k ( keys %refs ) {

			$self->debug_err ( "foreignKey:: K2=> $k [" . 
				$refs{$k}->[0] .  " - " . $refs{$k}->[1]);

			$query = $OpenCA::DBI::DB->{
				$self->{DB_Type}}->{FOREIGN_KEY};

			$col = $OpenCA::DBI::SQL->{VARIABLE}->{$k}[0];

			$myTable =
				$OpenCA::DBI::SQL->{TABLE}->{$table};

			$target_table =
				$OpenCA::DBI::SQL->{TABLE}->{$refs{$k}->[0]};

			$target_col =
				$OpenCA::DBI::SQL->{VARIABLE}->{$refs{$k}->[1]}[0];

			$query =~ s/__COL__/$col/g;
			$query =~ s/__TABLE__/$myTable/g;
			$query =~ s/__TARGET_COL__/$target_col/g;
			$query =~ s/__TARGET_TABLE__/$target_table/g;

			$self->debug_err( "foreignKey::query => $query" );
			$self->debug_err( "foreignKey::col => $col" );
			$self->debug_err( "foreignKey::target_table => $target_table" );
			$self->debug_err( "foreignKey::target_col => $target_col" );
		    	if ( not defined $self->doQuery ( QUERY => $query,
                                        BIND_VALUES => \@bind_values) ) {
                    	   $self->debug_err("upgradeDB: doQuery fail ($query)");
			   $self->rollback();
        	    	} else {
				$self->commit();
			}
		}
	} else {
		$self->debug_err ( "foreignKey:: NO FKeys for $table");
	}
    }

	my $update_cols = {
		CERTIFICATE => [ "ROWID", "NOTBEFORE", "SUSPENDED_AFTER","REVOKED_AFTER",
				 "INVALIDITY_REASON", "OWNER" ],
		CA_CERTIFICATE => [ "ROWID", "NOTBEFORE", "SUSPENDED_AFTER",
				    "REVOKED_AFTER", "INVALIDITY_DATE" ],
		REQUEST => [ "ROWID", "NOTBEFORE", "NOTAFTER", "APPROVED_AFTER",
			     "DELETED_AFTER", "ARCHIVED_AFTER", "OWNER",
			     "CA_CERTIFICATE_SERIAL" ],
		CRR => [ "ROWID", "NOTBEFORE", "NOTAFTER", "APPROVED_AFTER", 
			 "DELETED_AFTER", "ARCHIVED_AFTER", "OWNER" ],
		CRL => [ "ROWID" ],
		USER => [ "ROWID" ],
		USER_DATA => [ "ROWID" ],
		MESSAGES => ["ROWID"],
	};

	foreach my $table ( keys %$update_cols ) {
		my ( $myTable, $myCol, $def, $query );

		$myTable = $OpenCA::DBI::SQL->{TABLE}->{$table};
		foreach my $col ( @{$update_cols->{$table}} ) {
			$self->debug_err ( "updateDB: col update $table($col)");

			$myCol = $OpenCA::DBI::SQL->{VARIABLE}->{$col}[0];

			$def = $OpenCA::DBI::DB->{$self->{DB_Type}}->{TYPE}->{
                		$OpenCA::DBI::SQL->{VARIABLE}->{$col}[1]};

			$query = "alter table $myTable add column $myCol $def";
			$self->debug_err ( "updateDB: query $query");

		    	if ( not defined $self->doQuery ( QUERY => $query,
                                        BIND_VALUES => undef ) ) {
                    	   $self->debug_err("upgradeDB: doQuery fail ($query)");
			   $self->rollback();
        	    	} else {
				$self->commit();
			}
		}

		if ( $self->{DB_Type} =~ /MySQL/i ) {
			$query = "alter table $myTable ENGINE=InnoDB";

		    	if ( not defined $self->doQuery ( QUERY => $query,
                                        BIND_VALUES => undef ) ) {
                    	   $self->debug_err("upgradeDB: doQuery fail ($query)");
        	    	};
		}
	}

	## Fix for the Postgres_DB --- the DB is correct, but since we might
	## have empty owners, we need to DROP the NOT NULL constraint
    	if ( $self->{DB_Type} =~ /Pg/i ) {
	   	my $query = undef;

    		my @my_tables = ( "CERTIFICATE", "REQUEST", "CRR" );
    		foreach my $table ( @my_tables ) {

	   		$query = qq{ALTER TABLE } . 
				$OpenCA::DBI::SQL->{TABLE}->{$table} .
				qq{ ALTER COLUMN } .
				$OpenCA::DBI::SQL->{VARIABLE}->{OWNER}[0] .
				qq{ DROP NOT NULL};

		    	if ( not defined $self->doQuery ( QUERY => $query,
                                        BIND_VALUES => undef ) ) {
                    	   $self->debug_err("upgradeDB: doQuery fail ($query)");
			   $self->rollback();
        	    	} else {
				$self->commit();
			}
    		}
    	}

	## Now we need to update the (CA_)CERTIFICATE TABLES
	my @kList = $self->searchItems( DATATYPE=>"CA_CERTIFICATE", 
							MODE=>"KEYLIST" );
	foreach my $k ( @kList ) {
		my $cert = undef;

		$cert = $self->getItem ( DATATYPE=>"CA_CERTIFICATE", KEY=>"$k");
		next if ( not $cert );

		$self->debug_err ( "updating Certs: $k [" . 
					$cert->getParsed()->{CN} . "]" );

		$self->updateKey ( DATATYPE => "CA_CERTIFICATE", 
				KEY=>"$k",
				NEWKEY => $cert->getSerial("CA_CERTIFICATE") );
	}

	@kList = $self->searchItems( DATATYPE=>"CERTIFICATE", 
							MODE=>"KEYLIST" );
	foreach my $k ( @kList ) {
		my $cert = undef;

		$cert = $self->getItem ( DATATYPE=>"CERTIFICATE", KEY=>"$k");
		next if ( not $cert );

		$self->debug_err ( "updating Certs: $k [" . 
					$cert->getParsed()->{CN} . "]" );

		$self->updateItem ( DATATYPE=>"CERTIFICATE", KEY=>"$k",
				OBJECT => $cert );
	}

	@kList = $self->searchItems( DATATYPE=>"CRL", MODE=>"KEYLIST" );
	foreach my $k ( @kList ) {
		my $crl = undef;

		$crl = $self->getItem ( DATATYPE=>"CRL", KEY=>"$k");
		next if ( not $crl );

		$self->debug_err ( "updating CRL: $k [" . 
					$crl->getParsed()->{ISSUER} . "]" );

		$self->updateItem ( DATATYPE=>"CRL", KEY=>"$k",
				OBJECT => $crl );
	}

	return 1;
}

#####################################################################
#################### END of database initialization #################
#####################################################################

#####################################################################
## ----------------- storeItem related functions ----------------- ##
#####################################################################

## ##################################################################
## Function Name: updateItem
## ##################################################################

sub updateItem {

  my $self = shift;
  my $keys = { @_ };
  my $status = undef;

  if ( not defined $keys->{OBJECT} ) {
	$errval = $self->{gettext} ("Required Parameter OBJECT is missing.");
	return undef;
  }

  return $self->storeItem ( MODE=>"UPDATE", @_ );
}

sub updateKey {

   my $self = shift;
   my $keys = { @_ };
   my $status = undef;
   my @bind_values = ();

   if ( not defined $keys->{KEY} or not defined $keys->{NEWKEY} ) {
	$errval = $self->{gettext} ("Required Parameter is missing.");
	return undef;
   }

  my $table = $self->getTable ($keys->{DATATYPE});

  my $query = "update ". $OpenCA::DBI::SQL->{TABLE}->{$table} .  " set " . 
     $OpenCA::DBI::SQL->{VARIABLE}->{$table."_SERIAL"}[0]."=? ".
	" where ".  $OpenCA::DBI::SQL->{VARIABLE}->{$table."_SERIAL"}[0]."=?";

  push( @bind_values, $keys->{NEWKEY});
  push( @bind_values, $keys->{KEY});

  if ( not defined $self->doQuery ( QUERY => $query,
                                BIND_VALUES => \@bind_values) ) {
    $self->set_error ( $OpenCA::DBI::ERROR->{UPDATE_FAILED} );
    return undef;
  }

  return $keys->{NEWKEY};

}
## ##################################################################
## Function Name: storeItem
## ##################################################################

sub storeItem {

	## arguments miust be ransmitted via $arguments->{...}

	## Store a provided Item (DATA) provided the exact
	## DATATYPE. KEY (position in dB) data to match will
	## be automatically chosen on a DATATYPE basis.
  
	## The INFORM is used to get the data input format
	## PEM|DER|NET|SPKAC
  
	my $self = shift;
	my $keys = { @_ };

	$self->debug_err (">>>>>>>>>> updateItem: datatype => " .
 				$keys->{DATATYPE} . " / " .
 				$keys->{OBJECT}->{DATATYPE} );
 
	if ($keys->{DATATYPE} =~ /CERTIFICATE|REQUEST|CRR/ ) {
		my $status = undef;

		$status = $self->getStatus ( DATATYPE => $keys->{DATATYPE} );
		$keys->{OBJECT}->setStatus( $status )
	}

	$self->debug_err (">>>>>>>>>> updateItem: datatype => " .
		$keys->{DATATYPE} . " / " .
		$keys->{OBJECT}->{DATATYPE} );

	$self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

	$self->debug ("storeItem: Entering function storeItem");
 
	my %arguments  = $self->storeItem_getArguments ( @_ );
	## check for a correct run of storeItem_getArguments
	$self->debug ("storeItem: table: ".$arguments {TABLE});      

	## errno set by function
	return undef if (not defined $self->storeItem_checkData ( \%arguments ) );

	## why do we have a sub getTimeString ???
	$arguments {datetime} = getTimeString ();

	##   declare variables
	my $rv;

	## normal insertion of object
	if ($arguments {MODE} =~ /UPDATE/i) { 
		return undef if (not defined $self->storeItem_update ( \%arguments ));
	} else {
		return undef if (not defined $self->storeItem_insert ( \%arguments ));
	}

	###########################################
	## be warned: a serial can be a zero !!! ##
	###########################################
	$self->debug ("storeItem: succeeded - KEY: ".$arguments {KEY});  
	$self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );

	return $arguments {KEY};
}

## ##################################################################
## Function Name: storeItem_getArguments
## ##################################################################

sub storeItem_getArguments {

  ## parse the arguments

  my $self = shift;
  my $keys = { @_ };

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my %result;

  $self->debug ("storeItem_getArguments: Entering storeItem_getArguments");

  $result{MODE}       = $keys->{MODE};
  $result{MODULETYPE} = $keys->{MODULETYPE};
  $result{MODULE}     = $keys->{MODULE};
  $result{object}     = $keys->{OBJECT};

  return undef if ( not defined $keys->{OBJECT} );

  if ( not defined $keys->{DATATYPE} ) {
	$keys->{DATATYPE} = $keys->{OBJECT}->{DATATYPE};
  }

  $result {TABLE} = $self->getTable ($keys->{DATATYPE});
  $self->debug ("storeItem_getArguments: table: ".$result {TABLE});

  ## get all searchable attributes
  @{$result {attributes}} = 
  	$self->getSearchAttributes( DATATYPE=>$result {TABLE} );
  
  my $attr;

  my $object = $keys->{OBJECT};

  ## storeItem

  for $attr ( @{$result {attributes}} ) {
    my $value = undef; 

    $self->debug_err ( "storeItem_getArguments: $attr" );

    # We deal with email separately
    next if ( $attr =~ /^EMAIL$/ );

    my %k = %{ $keys };

    $value = undef;
    if ( exists $k{$attr} ) {
	$value = $k{$attr};
    } else {
    	if ( defined $object->getParsed()->{HEADER}->{$attr} ) {
		$self->debug_err ("storeItem_getArguments: $attr in " .
			"HEADER [".$object->getParsed()->{HEADER}->{$attr}."]");
		$value = $object->getParsed()->{HEADER}->{$attr};
    	} elsif ( defined $object->getParsed()->{$attr} ) {
		$self->debug_err("storeItem_getArguments: $attr in BODY [".
			$object->getParsed()->{$attr} . "]" );
		$value = $object->getParsed()->{$attr};
    	} elsif ( defined $object->getParsed()->{DN_HASH}->{$attr} ) {
		$self->debug_err ("storeItem_getArguments: $attr in DN_HASH [".
			$object->getParsed()->{DN_HASH}->{$attr}[0] . "]" );
		$value = $object->getParsed()->{DN_HASH}->{$attr}[0];
    	} elsif ( defined $object->{$attr} ) {
		$self->debug_err ("storeItem_getArguments: $attr in OBJECT [".
			$object->{$attr} . "]" );
		$value = $object->{$attr};
    	} else {
		$self->debug_err ("storeItem_getArguments: $attr NOT found!");
		$value = undef;
    	}
    };

    $self->debug_err ( "RESULT { $attr } = $value");

    # if ( utf8::is_utf8($value) ) {
# 	utf8::upgrade($value);
 #    };

    $result{$attr} = $value;
  }

  # Now fix the EMAIL attribute
  if ( defined $object->getParsed()->{EMAILADDRESSES} ) {
        $result {EMAILADDRESS} = "";
        $result {EMAIL} = "";
        foreach my $email (@{$object->getParsed()->{EMAILADDRESSES}}) {
            $result {EMAILADDRESS} .= "," if ($result {EMAILADDRESS});
            $result {EMAILADDRESS} .= $email;
            $result {EMAIL} .= "," if ($result {EMAIL});
            $result {EMAIL} .= $email;
        }

    	# if ( utf8::is_utf8($result{EMAILADDRESS}) ) {
	# 	print STDERR "VALUE is EMAILADDRESS UTF8 => " .
	# 			"$result{EMAILADDRESS}\n";
	# 	# utf8::decode($result{EMAILADDRESS});
    	# };

    	# if ( utf8::is_utf8($result{EMAIL}) ) {
	# 	print STDERR "VALUE is EMAIL UTF8 => " . $result{EMAIL} . "\n";
	# 	# utf8::decode($result{EMAIL});
    	# };
  }

  ## enforce status
  $result {STATUS} = $self->getStatus ( STATUS   => $result {STATUS},
                                        DATATYPE => $keys->{DATATYPE} );

  ## Get the Numeric Version of the current GMT time
  my $today = gmtime;
  my $numTodayValue = $self->{backend}->getNumericDate( "$today" );
  my $tempDate = undef;

  # print STDERR "storeItem_getArgs: RESULT{STATUS}   = " . $result{STATUS} ."\n";
  # print STDERR "storeItem_getArgs: numTodayValue    = $numTodayValue\n";

  # print STDERR "storeItem_getArgs: RESULT{NOTAFTER} = " .
	#	$result{NOTAFTER} . "\n";
  # print STDERR "storeItem_getArgs: RESULT{NOTBEFORE} = " .
	#	$result{NOTAFTER} . "\n";

  if ($result {NOTAFTER} ) {
	$tempDate = $self->{backend}->getNumericDate ( $result{NOTAFTER} );
	$result {STATUS} = "EXPIRED" if ( $tempDate < $numTodayValue);
  }

  if ($result {NOTBEFORE} ) {
	$tempDate = $self->{backend}->getNumericDate ( $result{NOTBEFORE} );
	$result {STATUS} = "EXPIRED" if ( $tempDate > $numTodayValue);
  }

  if ($result{NEXT_UPDATE}) {
	$tempDate = $self->{backend}->getNumericDate ( $result{NEXT_UPDATE} );
	$result {STATUS} = "EXPIRED" if ( $tempDate < $numTodayValue);
  }

  if ($result{LAST_UPDATE}) {
	$tempDate = $self->{backend}->getNumericDate ( $result{LAST_UPDATE} );
	$result {STATUS} = "EXPIRED" if ($tempDate > $numTodayValue);
  }

  # print STDERR "storeItem_getArgs: NEW STATUS   = " . $result{STATUS} ."\n";

  if (not $result {STATUS}) {
    delete ($result {STATUS});
    $self->debug ("storeItem_getArguments: status: erased because empty");
  } else {
    $self->debug ("storeItem_getArguments: status: ".$result {STATUS});
  }

  ## storage formats
  ##   If the data is convertible, let us have only one internal
  ##   format to handle with
  $result {INFORM} = $keys->{INFORM};
  if ( not $result {INFORM} ) {
    $result {INFORM} = "PEM";
  }
  $self->debug ("  storeItem_getArguments: inform: ".$result {INFORM});

  $result {KEY} = $object->getSerial ( $keys->{DATATYPE} );
  $self->debug_err (">>> storeItem::KEY => " . $result{KEY} );

  # $result {KEY} = $object->getParsed()->{HEADER}->{SERIAL};
  # $self->debug_err (">>> storeItem::KEY [2] => " . $result{KEY} );

  $result {CONVERTED} = $object->getItem ();
  if( $result {TABLE} =~ /(REQUEST|CRR)/i ) {
    $result {FORMAT} = $object->getParsed()->{TYPE};
  } else {
    $result {FORMAT} = "PEM";
  }
  $self->debug ("storeItem_getArguments: KEY:".$result{KEY});
  $self->debug ("storeItem_getArguments: format: ".$result {FORMAT});
  $self->debug ("storeItem_getArguments: converted: ".$result {CONVERTED});  

  $self->debug ("storeItem_getArguments: object->getParsed hash:");
  for my $h (keys %{$object->getParsed()}) {
      $self->debug ("storeItem_getArguments: object-attribute: $h");
      $self->debug ("storeItem_getArguments: object-value: ".$object->getParsed ()->{$h});
  }

  $self->debug ("storeItem_getArguments: function succesfully finished");

  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
  return %result;
}

## ##################################################################
## Function Name: storeItem_checkData
## ##################################################################

sub storeItem_checkData {

  ## checks all the available data
  ## warning: function must called with 
  #           storeItem_checkData { \%arguments} !!!

  my $self = shift;
  my $arguments = $_[0];

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  ## check data
  $self->debug ("storeItem_checkData: Entering storeItem_checkData");
  
  ##   determinate table
  if (not $arguments->{TABLE}) {
    # this is not allowed (for recovery too)
    $self->set_error ($OpenCA::DBI::ERROR->{WRONG_DATATYPE});
    return undef;
  }
  
  ## if VALID_* then take mode and in doubt use "UPDATE"
  ## else UPDATE
  ## special handling of CRLs
  ## all modes are now enforced !!!
  if ( not $arguments->{MODE} ) {
    if ( $arguments->{STATUS} =~ /^(VALID|NEW|RENEW)$/ ) {
      if ((uc $arguments->{MODE}) ne "UPDATE") {
        $arguments->{MODE} = "INSERT";
      } elsif ($arguments->{TABLE} eq "CRL") {
        ## blocks updating CRLs
        ## create a new one please
        $arguments->{MODE} = "INSERT";
      } else {
        $arguments->{MODE} = "UPDATE";
      }
    } elsif ( $arguments->{TABLE} eq "CRL" ) {
      ## blocks updating CRLs
      ## create a new one please
      $arguments->{MODE} = "INSERT";
    } else {
      $arguments->{MODE} = "UPDATE";
    }
  }

  ## if no moduletype then unknown
  if (not $arguments->{MODULETYPE}) {
    $arguments->{MODULETYPE} = "UNKNOWN";
    if ($arguments->{MODULE}) {
      $arguments->{MODULE} .= " - UNKNOWN MODULETYPE";
    } else {
      $arguments->{MODULE} = "UNKNOWN MODULETYPE AND UNKNOWN MODULE";
    }
  }
  ## if no module then "UNKNOWN MODULE"
  if (not $arguments->{MODULE}) {
    $arguments->{MODULE} = "UNKNOWN MODULE";
  }

  ##   if we have no object then return
  if (not $arguments->{object}) {
    $self->set_error ($OpenCA::DBI::ERROR->{NO_OBJECT});
    return undef;
  }

  my $query = undef;
  my @bind_values = ();
  my @bind_types = ();

  ## is item existent and unique ?
  $self->debug ("storeItem_checkData: check for existence of item");  
  $query = "select * from ".$OpenCA::DBI::SQL->{TABLE}->{$arguments->{TABLE}}." where ". 
           $OpenCA::DBI::SQL->{VARIABLE}->{$arguments->{TABLE}."_SERIAL"}[0]."=?";
  undef @bind_values;
  $bind_values[0] = $arguments->{KEY};
  $bind_types [0] = $OpenCA::DBI::SQL->{VARIABLE}->{$arguments->{TABLE}."_SERIAL"}[1];

  $self->debug_err ("storeItem_checkData: doQuery: $query");  
  $self->debug_err ("storeItem_checkData: bind_values: @bind_values\n");
  $self->debug_err ("storeItem_checkData: bind_types: @bind_types\n");

  if ( not defined $self->doQuery ( QUERY => $query, 
		BIND_VALUES => \@bind_values, BIND_TYPES => \@bind_types) ) {
    $self->debug_err ("storeItem_checkData: doQuery failure detected");  
    $self->set_error ( $OpenCA::DBI::ERROR->{SELECT_FAILED} );
    return undef;
  }
 
  my $rv = $self->{STH}->fetchrow_arrayref;

  ## normal insertion of object
  if (defined $rv and $rv) {
    if (defined $arguments->{MODE} and ($arguments->{MODE} =~ /INSERT/)) {
      $self->debug_err ("storeItem_checkData: illegal insert");  
      $self->set_error ( $OpenCA::DBI::ERROR->{ENTRY_EXIST} );
      return undef;
    } else {
      $arguments->{MODE} = "UPDATE";
    }
  } else {
	my @call = caller;
    if (defined $arguments->{MODE} and ($arguments->{MODE} =~ /UPDATE/)) {
      $self->debug ("storeItem_checkData: illegal update");  
      $self->set_error ( $OpenCA::DBI::ERROR->{ENTRY_NOT_EXIST} );
      return undef;
    } else {
      $arguments->{MODE} = "INSERT";
    }
  }

  $self->debug ("storeItem_checkData: data is complete");  
  $self->debug ("storeItem_checkData: leaving function successfully");  

  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
  return 1;
}

## ##################################################################
## Function Name: storeItem_update
## ##################################################################

sub storeItem_update {

  my $self = shift;
  my $arguments = $_[0];

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my $query = undef;
  my @bind_values = ();
  my @bind_types = ();

  $self->debug ("storeItem_upate: update mode");  
  ## item existent
  ## ok this could be CRR, Request or Certificate
  ##   verify actual state (check signatures)
  ##     -- (I think that is not the job of the DBI-Module - so it is not implemented)
  ##   check all input data
  ##     -- this should be done earlier 
  ##     -- (attriubtes are checked directly before storing them)
  ##   is this statechange allowed (for example to prevent multiple DNs)
  ##     -- actually not implemented (do statechange only)
  ##   try statechange
  ##     -- prepare query
  $self->debug ("storeItem_update: prepare query");  
  $query = "update ".$OpenCA::DBI::SQL->{TABLE}->{$arguments->{TABLE}}." set ".
  		$OpenCA::DBI::SQL->{VARIABLE}->{DATA}[0]."=?, ".
  		$OpenCA::DBI::SQL->{VARIABLE}->{FORMAT}[0]."=? ";

  push( @bind_values, $arguments->{CONVERTED});
  push( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{DATA}[1]);

  push( @bind_values, $arguments->{FORMAT});
  push( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{FORMAT}[1]);

  ##     -- adding searchattributes - never update a date !!!
  ##     -- getSearchAttributes does not return date as attribute
  for my $attr ( @{$arguments->{attributes}} ) {
    if ( ($attr) and ( $attr !~ /^KEY|ROWID$/ ) ) {

	if ( $OpenCA::DBI::SQL->{VARIABLE}->{$attr}[0] eq "" ) {
		#print STDERR "ERR::PARAM MISMATCH::$attr\n";
		next;
	}

      $query .= ", ".$OpenCA::DBI::SQL->{VARIABLE}->{$attr}[0]."=?";
      push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$attr}[1] );

      if ( $attr =~ /NOTBEFORE|NOTAFTER|LAST_UPDATE|NEXT_UPDATE|EXPIRES_AFTER|SUBMIT_DATE|LAST_ACTIVITY|SUSPENDED_AFTER|REVOKED_AFTER|APPROVED_AFTER|ARCHIVED_AFTER|DELETED_AFTER/ ) {
	if ( $arguments->{$attr} ne "" ) {
		$arguments->{$attr} = $self->{backend}->getNumericDate ( 
			$arguments->{$attr} );
	}
      }

      $self->debug_err ( "storeItem_update: $attr converted to: " .
			$arguments->{$attr} );

      push( @bind_values, $arguments->{$attr} );
    }
  }

  ##     -- set serials
  $query .= " where ".
       $OpenCA::DBI::SQL->{VARIABLE}->{$arguments->{TABLE}."_SERIAL"}[0]."=?";

  push( @bind_values, $arguments->{KEY});
  push( @bind_types, 
	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments->{TABLE}."_SERIAL"}[1]);

  foreach my $help (@bind_values) {
    	$self->debug ("storeItem_update: bind_values: $help");
  }
  $self->debug ("storeItem_update: query complete, call doQuery");  
  $self->debug_err ("storeItem_update: query: $query");
  $self->debug_err ("storeItem_update: bind_values: @bind_values");
  $self->debug_err ("storeItem_update: bind_types: @bind_types");

  if ( not defined $self->doQuery ( QUERY => $query, 
				BIND_VALUES => \@bind_values,
				BIND_TYPES => \@bind_types) ) {

    $self->set_error ( $OpenCA::DBI::ERROR->{UPDATE_FAILED} );
    return undef;
  }

  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
  return 1;
}

## ##################################################################
## Function Name: storeItem_insert
## ##################################################################

sub storeItem_insert {

  my $self = shift;
  my $arguments = $_[0];

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my $query = undef;
  my @bind_values = ();
  my @bind_types = ();

  $self->debug ("storeItem_insert: Entering storeItem_insert");  
  ## INSERT
  ##   mode='update' is allowed in the future to support revoking non-existing request 
  ##   check all input data
  ##     -- this should be done earlier 
  ##     -- (attriubtes are checked directly before storing them)
  ##   is this statechange allowed (for example renewal nonexistent request)
  ##     -- actually not implemented (do statechange only)
  ##   create row with all additional attributes
  ##     -- prepare query
  $self->debug ("storeItem_insert: prepare query");  
  $query = "insert into ".
    $OpenCA::DBI::SQL->{TABLE}->{$arguments->{TABLE}}." ( ".
    $OpenCA::DBI::SQL->{VARIABLE}->{$arguments->{TABLE}."_SERIAL"}[0].", ".
    $OpenCA::DBI::SQL->{VARIABLE}->{DATA}[0].", ".
    $OpenCA::DBI::SQL->{VARIABLE}->{FORMAT}[0]." ";
  for my $attr ( @{$arguments->{attributes}} ) {
    $query .= ", ".$OpenCA::DBI::SQL->{VARIABLE}->{$attr}[0]
      if ($attr !~ /^KEY$/ and $arguments->{$attr});
  }

  # if ($arguments->{TABLE} =~ /CERTIFICATE/i) {
  #   $query .= ", ".$OpenCA::DBI::SQL->{VARIABLE}->{NOTAFTER}[0];
  # }

  $query .= ") VALUES (";

  ##     -- adding data, format, status
  $query .= " ?, ?, ?";

  push(@bind_values, $arguments->{KEY});
  push(@bind_types, 
	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments->{TABLE}."_SERIAL"}[1]);

  push(@bind_values, $arguments->{CONVERTED});
  push(@bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{DATA}[1]);

  push(@bind_values, $arguments->{FORMAT});
  push(@bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{FORMAT}[1]);

  $self->debug ("storeItem_insert: try to parse header");  
  ##     -- adding searchattributes - never update a date !!!
  ##     -- getSearchAttributes does not return date as attribute
  for my $attr ( @{$arguments->{attributes}} ) {
    if ($attr !~ /^KEY$/ and $arguments->{$attr}) {
      # so transformation should be correct for SQL
      $self->debug ("storeItem_insert: attr: $attr");
      $query .= ", ?";
      if ( $attr =~ /NOTBEFORE|NOTAFTER|LAST_UPDATE|NEXT_UPDATE|EXPIRES_AFTER|SUBMIT_DATE|LAST_ACTIVITY|SUSPENDED_AFTER|REVOKED_AFTER|APPROVED_AFTER|ARCHIVED_AFTER|DELETED_AFTER/ ) {
	$arguments->{$attr} = $self->{backend}->getNumericDate ( 
			$arguments->{$attr} );
     	$self->debug_err ( "storeItem_insert: $attr converted to: " .
			$arguments->{$attr} );
      };

      push ( @bind_values, $arguments->{$attr} );
      push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$attr}[1]);
    }
  }

  $query .= ")";
      
  foreach my $help (@bind_values) {
    $self->debug ("storeItem_insert: bind_values: $help");
  }
  $self->debug ("storeItem_insert: query complete, call doQuery");  

  $self->debug_err ( "storeItem_insert: $query");
  # for ( my $i = 0 ; $i <$#bind_values; $i++ ) {
  # 	$self->debug_err ( "storeItem_insert: [$i]" . 
# 				substr($bind_values[$i], 0, 60));
 #  }

  # print STDERR "insert: $query\n";
  $self->debug_err("storeItem_insert: bind_values: @bind_values");
  $self->debug_err("storeItem_insert: bind_types: @bind_types");

  if ( not defined $self->doQuery (QUERY => $query, 
				BIND_VALUES => \@bind_values,
				BIND_TYPES => \@bind_types) ) {
    $self->set_error ( $OpenCA::DBI::ERROR->{INSERT_FAILED} );
    return undef;
  }

  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
  return 1;

}

####################################
## end of storeItem related stuff ##
####################################

## ##################################################################
## Function Name: updateStatus
## ##################################################################

sub updateStatus {
  
  my $self = shift;
  my $keys = { @_ };
  
  my $new_status = $keys->{STATUS};
  my $new_datatype = $keys->{NEWTYPE};
  my $item = $keys->{OBJECT};

  return undef if ( not $item );
 
  if ( not $new_status ) {
	if ( not $new_datatype ) {
		return undef;
	}
	if( $new_datatype =~ /^([^\_]+)\_/ ) {
		$new_status = $1;
	} else {
		return undef;
	}
  }

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );
  $item->setStatus ( "$new_status");

  return $self->updateItem ( OBJECT => $item );

}

## ##################################################################
## Function Name: getItem
## ##################################################################

sub getItem {

  ## Get an Item provided the exact data to match:
  ## DATATYPE, KEY. Will return, if exists, the data
  ## on the corresponding dB file.
  
  ## Actually, as the search function, the returned
  ## value will be a referenced object (REQ, X509,
  ## CRL, etc... ).
  
  my $self = shift;
  
  $self->debug ("getItem: Entering sub getItem");

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my ( $fileName, $item, $body, $header, $hash, $tmpBody );
  
  my %arguments = $self->getArguments ( @_ );
  return undef if (not %arguments);

  my $query = undef;
  my @bind_values = ();
  my @bind_types = ();

  ## support for direct access to latest CRL
  if ((not defined $arguments{KEY}) && ($arguments{TABLE} ne "CRL")) {
    $self->set_error ( $OpenCA::DBI::ERROR->{ MISSING_ARG_SERIAL } );
    return undef;
  }

  $self->debug ("getItem: data complete");  

  ## I hope the people only search for Certs, Requests and CRRs
  ## mmh this is impossible
  $query = "select ";

  my @cols = @{$OpenCA::DBI::SQL->{TABLE_STRUCTURE}->{$arguments{TABLE}}};
  for (my $i = 0; $i <= $#cols; $i++) {
	$query .= $OpenCA::DBI::SQL->{VARIABLE}->{$cols[$i]}[0] . " ";
	$query .= ", " if ( $i < $#cols );
  };

  $query .= " from ".$OpenCA::DBI::SQL->{TABLE}->{$arguments{TABLE}} .
							" where ";

  if (defined $arguments{KEY}) {
    if ($arguments{TABLE} =~ /^CA_CERTIFICATE/i) {
        $query .= "(" . $OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE} .
						"_SERIAL"}[0]." like ?)";
    } else {
        $query .= "(" . $OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE} .
						"_SERIAL"}[0]."=?)";
    }
    push ( @bind_values, $arguments{KEY} );
    push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[1]);

    if (($arguments{STATUS} =~ /REVOKED|SUSPENDED/ ) and 
				($arguments{TABLE} =~ /^CERTIFICATE/i)) {
    	$query .= " and (" . $OpenCA::DBI::SQL->{VARIABLE}->{STATUS}[0] .
 					" like ?)";
    	push ( @bind_values, $arguments{STATUS} );
        push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{STATUS}[1]);
    }
  } else {
    ## to support most actual CRL (you can use it find the last cert etc. too)
    $query .= $OpenCA::DBI::SQL->{VARIABLE}->{DATE}[0]." like (select MAX(" .
		$OpenCA::DBI::SQL->{VARIABLE}->{LAST_UPDATE}[0] .
		") from " . $OpenCA::DBI::SQL->{TABLE}->{$arguments{TABLE}}.")";
    undef @bind_values;
  }

  # print STDERR "QUERY => $query\n";
  # print STDERR "VALUES => @bind_values\n";
  # print STDERR "VALUES => @bind_types\n";

  my ($rv);

  ## do_query
  if ( not defined $self->doQuery (QUERY => $query, 
		BIND_VALUES => \@bind_values, BIND_TYPES  => \@bind_types) ) {
    $self->set_error ( $OpenCA::DBI::ERROR->{SELECT_FAILED} );
    $self->debug_err ( "getItem: failedQuery: query: $query");
    $self->debug_err ( "getItem: failedQuery: bind_values: @bind_values");
    $self->debug_err ( "getItem: failedQuery: bind_types: @bind_types");
    return undef;
  }

  ## STH->rows does not work with Oracle (DB2 does not like rows sometimes too)
  my $arrayref = $self->{STH}->fetchrow_arrayref;
  if (not defined $arrayref or not $arrayref) {
    return undef;
  }

  return $self->getResultItem (ARGUMENTS => \%arguments, 
					ARRAYREF => $arrayref);

}

## ##################################################################
## Function Name: getPrevItem
## ##################################################################

sub getPrevItem {

  ## Get an Item provided the exact data to match:
  ## DATATYPE, KEY. Will return, if exists, the data
  ## on the corresponding dB file.
  
  ## Actually, as the search function, the returned
  ## value will be a referenced object (REQ, X509,
  ## CRL, etc... ).
  
  my $self = shift;

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my %arguments = $self->getArguments ( @_ );
  return undef if (not %arguments);

  my $query = undef;
  my @bind_values = (); 
  my @bind_types = (); 

  ## Let us make some needed check
  if (not $arguments{TABLE}) {
    $self->set_error ( $OpenCA::DBI::ERROR->{ MISSING_ARG_TABLE } );
    return undef;
  }

  # if ( not exists $arguments{KEY} ) {
  #   if ($arguments{TABLE} eq "CA_CERTIFICATE" or
   #      			$arguments{TABLE} eq "CA") {
   #      $arguments{KEY} = "";
   #  } else {
   #      $arguments{KEY} = -1;
   #  }
   #  return undef;
  # }

  my $and = 0;
  $query = "SELECT " . $OpenCA::DBI::SQL->{VARIABLE}->{ROWID}[0] . ", " .
	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[0] .
	" from " . $OpenCA::DBI::SQL->{TABLE}->{$arguments{TABLE}};

  if (defined $arguments{KEY} and $arguments{KEY} ne "-1" ) {
    $query .= " where ".
	$OpenCA::DBI::SQL->{VARIABLE}->{ROWID}[0] . " < ( " .
	" select " . $OpenCA::DBI::SQL->{VARIABLE}->{ROWID}[0] . " from " .
	$OpenCA::DBI::SQL->{TABLE}->{$arguments{TABLE}} . " where " .
        $OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[0] .
	" = ? ) ";
    push (@bind_values, $arguments{KEY});
    push (@bind_types, 
	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[1]);
    $and = 1;
  }

  $query .= " ORDER BY " .
	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_ORDERBY"}[0] .
	" DESC";

  # print STDERR "getPrevItem: query: $query\n";
  # print STDERR "getPrevItem: bind_values: @bind_values\n";
  # print STDERR "getPrevItem: bind_types: @bind_types\n";

  ## do_query
  if ( not defined $self->doQuery (QUERY => $query, 
		BIND_VALUES => \@bind_values, BIND_TYPES => \@bind_types) ) {
    $self->set_error ( $OpenCA::DBI::ERROR->{SELECT_FAILED} );
    return undef;
  }

  my $ref = $self->{STH}->fetchrow_arrayref;

  $self->debug_err ("getPrevItem: arg: " . $arguments{KEY});
  $self->debug_err ("getPrevItem: result: " . $ref->[0]);
  $self->debug_err ("getPrevItem: result: " . $ref->[1]);

  # print STDERR "getPrevItem: arg: " . $arguments{KEY} . "\n";
  # print STDERR "getPrevItem: rawid: " . $ref->[0] . "\n";
  # print STDERR "getPrevItem: serial: " . $ref->[1] . "\n";

  if (defined $ref and exists $ref->[0] and $ref->[0] ne "") {
    return $self->getItem (DATATYPE => $arguments{TABLE},
                           KEY      => $ref->[1],
                           MODE     => $arguments{MODE}
                          );
  } else {
    if ((defined $ref) or (not defined $self->{STH}->err)) {
      $self->debug ("getNextItem: there is no next item");
      $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
      return undef; ## no errors no results
    } else { # mmh this should never happen here
      $self->set_error ( $OpenCA::DBI::ERROR->{SELECT_FAILED} );
      return undef;
    }
  }
  
  ## never reached
  $self->set_error ( $OpenCA::DBI::ERROR->{UNEXPECTED_ERROR} );
  return undef;
}

## ##################################################################
## Function Name: getNextItem
## ##################################################################

sub getNextItem {

  ## Get an Item provided the exact data to match:
  ## DATATYPE, KEY. Will return, if exists, the data
  ## on the corresponding dB file.
  
  ## Actually, as the search function, the returned
  ## value will be a referenced object (REQ, X509,
  ## CRL, etc... ).
  
  my $self = shift;

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my %arguments = $self->getArguments ( @_ );
  return undef if (not %arguments);

  my $query = undef;
  my $rowid = -1;
  my @bind_values = (); 
  my @bind_types = (); 

  ## Let us make some needed check
  if (not $arguments{TABLE}) {
    $self->set_error ( $OpenCA::DBI::ERROR->{ MISSING_ARG_TABLE } );
    return undef;
  }

  # if ( $arguments{KEY} ) {
  #   $query = "select ". $OpenCA::DBI::SQL->{VARIABLE}->{ROWID}[0] . ", " .
 #	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[0] .
 #	" from " . $OpenCA::DBI::SQL->{TABLE}->{$arguments{TABLE}} . 
 #	" where " . 
 #	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[0] .
 #	" = ?";
 #	push(@bind_values, $arguments{KEY});
 #    	push(@bind_types, 
 ##	    $OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[1]);
#
#  	## do_query
#  	if ( not defined $self->doQuery (QUERY => $query, 
#		BIND_VALUES => \@bind_values, BIND_TYPES => \@bind_types) ) {
##   	$self->set_error ( $OpenCA::DBI::ERROR->{SELECT_FAILED} );
#    	return undef;
#  }
#  my $ref = $self->{STH}->fetchrow_arrayref;

  $self->debug_err ("getNextItem: arg: " . $arguments{KEY});
	
#  }

  ## I hope the people only search for Certs, Requests and CRRs
  ## mmh this is impossible
  my $and = 0;
  $query = "select ". $OpenCA::DBI::SQL->{VARIABLE}->{ROWID}[0] . ", " .
	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[0] .
	" from " . $OpenCA::DBI::SQL->{TABLE}->{$arguments{TABLE}};

  if (defined $arguments{KEY} and $arguments{KEY} ne "-1" ) {
    $query .= " where ".
	$OpenCA::DBI::SQL->{VARIABLE}->{ROWID}[0] . " > ( " .
	" select " . $OpenCA::DBI::SQL->{VARIABLE}->{ROWID}[0] . " from " .
	$OpenCA::DBI::SQL->{TABLE}->{$arguments{TABLE}} . " where " .
        $OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[0] .
	" = ? )";
    push (@bind_values, $arguments{KEY});
    push (@bind_types, 
	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[1]);
    $and = 1;
  }

  $query .= " ORDER BY " .
	$OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_ORDERBY"}[0];

  ## do_query
  if ( not defined $self->doQuery (QUERY => $query, 
		BIND_VALUES => \@bind_values, BIND_TYPES => \@bind_types) ) {
    $self->set_error ( $OpenCA::DBI::ERROR->{SELECT_FAILED} );
    return undef;
  }
  my $ref = $self->{STH}->fetchrow_arrayref;

  $self->debug_err ("getNextItem: arg: " . $arguments{KEY});
  $self->debug_err ("getNextItem: result: " . $ref->[0]);
  $self->debug_err ("getNextItem: result: " . $ref->[1]);

  if (defined $ref and exists $ref->[0] and $ref->[0] ne "") {
    return $self->getItem (DATATYPE => $arguments{TABLE},
                           KEY      => $ref->[1],
                           MODE     => $arguments{MODE}
                          );
  } else {
    if (defined $ref or
        not defined $self->{STH}->err) {
      $self->debug ("getNextItem: there is no next item");
      $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
      return undef; ## no errors no results
    } else { # mmh this should never happen here
      $self->set_error ( $OpenCA::DBI::ERROR->{SELECT_FAILED} );
      return undef;
    }
  }
  
  ## never reached
  $self->set_error ( $OpenCA::DBI::ERROR->{UNEXPECTED_ERROR} );
  return undef;

}

## ##################################################################
## Function Name: deleteItem
## ##################################################################

sub deleteItem {
  ## it is not neccessary to delete an object if it is revoked/marked
  ## as deleted
  return 1;
}

## ##################################################################
## Function Name: destroyItem
## ##################################################################

sub destroyItem {
  ## attention this code is not for normal use only for recovery reasons !
  ## if you want to say a request is deleted than storeItem with
  ## STATUS = $OpenCA::DBI::status->{DELETED}

  ## Get an Item provided the exact data to match:
  ## DATATYPE, KEY. Will return, if exists, the data
  ## on the corresponding dB file.
  
  ## Actually, as the search function, the returned
  ## value will be a referenced object (REQ, X509,
  ## CRL, etc... ).
  
  my $self = shift;
  my $keys = { @_ };
  
  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my $type  = $keys->{DATATYPE};
  my $table = $self->getTable ($type);
  
  my $serial = $keys->{KEY};  ## Key passed when stored item

  my $query = undef;
  my @bind_values = ();
  my @bind_types = ();

  ## Let us make some needed check
  if (not $table) {
    $self->set_error ( $OpenCA::DBI::ERROR->{MISSING_ARG_TABLE} );
    return undef;
  }
  if (not $serial and ($serial != 0)) {
    $self->set_error ( $OpenCA::DBI::ERROR->{MISSING_ARG_SERIAL} );
    return undef;
  }

  ## I hope the people only search for Certs, Requests and CRRs
  ## mmh this is impossible
  ## Attention date is not numeric !!!
  $query = "delete from ".$OpenCA::DBI::SQL->{TABLE}->{$table}." where ".
	$OpenCA::DBI::SQL->{VARIABLE}->{$table."_SERIAL"}[0]."= ? ".
  push ( @bind_values, $serial);
  push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$table."_SERIAL"}[1]);

  ## do_query
  if ( not defined $self->doQuery (QUERY => $query, 
	BIND_VALUES => \@bind_values, BIND_TYPES => \@bind_types) ) {
	$self->set_error ( $OpenCA::DBI::ERROR->{DELETE_FAILED} );
	return undef;
  }

  ## successful
  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
  return 1;

}


## ##################################################################
## Function Name: Search Items
## ##################################################################

sub elements {

  ## Get an Item provided the exact data to match:
  ## DATATYPE, KEY. Will return, if exists, the data
  ## on the corresponding dB file.
  
  ## Actually, as the search function, the returned
  ## value will be a referenced object (REQ, X509,
  ## CRL, etc... ).
  
	my $self = shift;
	return $self->searchItems( MODE=>"COUNT", @_ );
}

## ##################################################################
## Function Name: Search Items
## ##################################################################

sub searchItems { # new one !!!

  ## Get an Item provided the exact data to match:
  ## DATATYPE, KEY. Will return, if exists, the data
  ## on the corresponding dB file.
  
  ## Actually, as the search function, the returned
  ## value will be a referenced object (REQ, X509,
  ## CRL, etc... ).
  
  my $self = shift;
  
  my $keys = { @_ };

  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );

  my (@retList, @objRetList);
  my ( $items );

  $self->debug ("searchItems: Entering function searchItems");
  $self->debug ("searchItems: OpenCA::DBI::errno: $errno");

  my %arguments = $self->getArguments ( @_ );

  $self->debug ("searchItems: OpenCA::DBI::errno: $errno");

  return undef if ($errno);

  $self->debug ("searchItems: dbi-status:".$arguments {STATUS});

  my $query = undef;
  my @bind_values = ();
  my @bind_types = ();

  ## Let us make some needed check
  if (not $arguments {TABLE}) {
    $self->set_error ( $OpenCA::DBI::ERROR->{MISSING_ARG_TABLE} );
    return undef;
  }
  
  ## let us prepare the question
  my $and = 0;
  my $mode = "*";
  my $today = gmtime;
  my $now = $self->{backend}->getNumericDate( "$today" );

  if ( $arguments { MODE } =~ /ROWS|COUNT/ ) {
	$mode = "count(*)";
  } elsif ( $arguments { MODE } =~ /KEYLIST/ ) {
	$mode = $OpenCA::DBI::SQL->{VARIABLE}->{$arguments {TABLE}.
							"_SERIAL"}[0];
  } else {
	$mode = '*';
  }

  $query = "select $mode from " . 
		$OpenCA::DBI::SQL->{TABLE}->{$arguments {TABLE}};

  ## check for unique identifier scan
  if ( $arguments{KEY} and ($arguments {TABLE} =~ /CERTIFICATE/ ) ) {
    if ($and) {
      $query .= " and ";
    } else {
      $query .= " where ";
      $and = 1;
    }
    if ( $arguments {TABLE} =~ /CA_CERTIFICATE/ ) {
    	$query .= "(".$OpenCA::DBI::SQL->{VARIABLE}->{CA_CERTIFICATE_SERIAL}[0]."=?)";
    } else {
    	$query .= "(".$OpenCA::DBI::SQL->{VARIABLE}->{CERTIFICATE_SERIAL}[0]."=?)";
    }

    ## prepare bind_values
    push ( @bind_values, $arguments{KEY});
    push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{CERTIFICATE_SERIAL}[1]);
    ## delete from keys
    delete $arguments{KEY};
  }

  if ( $arguments {EXPIRES_BEFORE} or $arguments {EXPIRES_AFTER} ) {
	delete $arguments { STATUS };
  } else {
	if ( $arguments { STATUS } =~ /EXPIRED/i ) {
		$arguments { EXPIRES_BEFORE } = $now;
		delete $arguments { STATUS };
	} elsif ( $arguments { STATUS } =~ /VALID/ ) {
		$arguments { EXPIRES_AFTER } = $now;
		# delete $arguments { STATUS };
	}
  }

  $self->debug(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<\n");
  $self->debug("EXPIRES_BEFORE => " . $arguments {EXPIRES_BEFORE} . "\n");
  $self->debug("EXPIRES_AFTER => " . $arguments {EXPIRES_AFTER} . "\n");
  $self->debug("TABLE => " . $arguments {TABLE} . "\n");
  $self->debug(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<");

  if ( $arguments {EXPIRES_BEFORE} and 
			($arguments {TABLE} =~ /CERTIFICATE/ ) ) {
    if ($and) {
      $query .= " and ";
    } else {
      $query .= " where ";
      $and = 1;
    }
    $query .= "(".$OpenCA::DBI::SQL->{VARIABLE}->{NOTAFTER}[0]." < ? )";
    ## prepare bind_values
    push( @bind_values, $arguments{EXPIRES_BEFORE} );
    push( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{NOTAFTER}[1]);
    ## delete from keys
    delete $arguments{EXPIRES_BEFORE};
  }

  if ( $arguments {EXPIRES_AFTER} and 
  			($arguments {TABLE} =~ /CERTIFICATE/ ) ) {
    if ($and) {
      $query .= " and ";
    } else {
      $query .= " where ";
      $and = 1;
    }
    $query .= "(".$OpenCA::DBI::SQL->{VARIABLE}->{NOTAFTER}[0]." > ? )";
    ## prepare bind_values
    push ( @bind_values, $arguments{EXPIRES_AFTER} );
    push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{NOTAFTER}[1]);
    ## delete from keys
    delete $arguments{EXPIRES_AFTER};
  }

  if ( $arguments {EXPIRES_BEFORE} and 
	  			($arguments {TABLE} =~ /^CRL/ ) ) {
    if ($and) {
      $query .= " and ";
    } else {
      $query .= " where ";
      $and = 1;
    }
    $query .= "(".$OpenCA::DBI::SQL->{VARIABLE}->{NEXT_UPDATE}[0]." < ? )";
    ## prepare bind_values
    push ( @bind_values, $arguments{EXPIRES_BEFORE} );
    push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{NEXT_UPDATE}[1]);
    ## delete from keys
    delete $arguments{EXPIRES_BEFORE};
  }

  if ( $arguments {EXPIRES_AFTER} and 
	  			($arguments {TABLE} =~ /^CRL/ ) ) {
    if ($and) {
      $query .= " and ";
    } else {
      $query .= " where ";
      $and = 1;
    }
    $query .= "(".$OpenCA::DBI::SQL->{VARIABLE}->{NEXT_UPDATE}[0]." > ? )";
    ## prepare bind_values
    push ( @bind_values, $arguments{EXPIRES_AFTER} );
    push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{NEXT_UPDATE}[1]);
    ## delete from keys
    delete $arguments{EXPIRES_AFTER};
  }

  if ( $arguments{FROM} ) {
 
    if ($and) {
      $query .= " and ";
    } else {
      $query .= " where ";
      $and = 1;
    }
    $query .= "(".$OpenCA::DBI::SQL->{VARIABLE}->{ROWID}[0]." >= ? ) ";
    push ( @bind_values, $arguments{FROM} );
    push ( @bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{ROWID}[1]);
    delete $arguments{FROM};
  }

  if ( $arguments { ITEMS } ) { 
	$items = $arguments{ITEMS};
	delete $arguments{ITEMS};
  }

  $self->debug ("searchItems: query now: $query");

  ## For every keyword let us get the list of values
  my @attributes = $self->getSearchAttributes (DATATYPE=>$arguments {TABLE});

  my $attr;
  my $array = 0;
  my @arrayVal = ();

  for $attr ( @attributes ) {
    $self->debug ("searchItems: scan attribute: $attr");

    if ($arguments {$attr}) {
      $self->debug ("searchItems: attribute's content: ".$arguments {$attr});

      ## get from keys
      if ($and) {
	$query .= " and ";
      } else {
	$query .= " where ";
	$and = 1;
      }
      if ( ref($arguments {$attr}) =~ /ARRAY/ ) {
	      $self->debug ( "ARGUMENT IS AN ARRAY!!!\n");
	      $array = 1;
	      @arrayVal = @{ $arguments{$attr}};
      } else {
	      $array = 0;
	      @arrayVal = ( $arguments{$attr} );
      }

      if ($attr =~ /^KEY$/) {
        $query .= "(".
          $OpenCA::DBI::SQL->{VARIABLE}->{$arguments {TABLE}."_SERIAL"}[0];
	  
	if( $array eq "1" ) {
		$query .= " in ( ";
		foreach my $tmpVal ( @arrayVal ) {
			$query .= " ? ,";
                        push (@bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[1]);
		}
		$query =~ s/,$//;
		$query .= " ) ";
	} else {
	  $query .= "= ? ";
          push (@bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$arguments{TABLE}."_SERIAL"}[1]);
	}
	$query .= ") ";

      } elsif ($OpenCA::DBI::SQL->{VARIABLE}->{$attr}[1] =~ /BIGINT/i) {
        $self->debug ("searchItems: BIGINT: ".
                      $attr." --&gt; ".
                      $OpenCA::DBI::SQL->{VARIABLE}->{$attr}[1]);
        $query .= "( ".$OpenCA::DBI::SQL->{VARIABLE}->{$attr}[0];

	if( $array eq "1" ) {
		$query .= " in ( ";
		foreach my $tmpVal ( @arrayVal ) {
			$query .= " ? ,";
                        push (@bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$attr}[1]);
		}
		$query =~ s/,$//;
		$query .= " ) ";
	} else {
	  $query .= " = ? ";
          push (@bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$attr}[1]);
	}

	$query .= ") ";

      } else {
        $self->debug ("searchItems: TEXT: ".
                      $attr." --&gt; ".
                      $OpenCA::DBI::SQL->{VARIABLE}->{$attr}[1]);

        $query .= "(".$OpenCA::DBI::SQL->{VARIABLE}->{$attr}[0];

	if( $array eq "1" ) {
		$query .= " in ( ";
		foreach my $tmpVal ( @arrayVal ) {
		 	$query .= " ? ,";
                        push (@bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$attr}[1]);
		}
		$query =~ s/,$//;
		$query .= " ) ";
	} else {
	  $query .= " like ? ";
          push (@bind_types, $OpenCA::DBI::SQL->{VARIABLE}->{$attr}[1]);
	}

	$query .= ") ";

      }

      if ( $array eq "1" ) {
	      push ( @bind_values, @arrayVal );
      } else {
	      ## prepare bind_values
      	      $bind_values [scalar (@bind_values)] = $arguments {$attr};
      };

      ## delete from keys
      delete $arguments{$attr};
    }
  }

  if ( $mode ne "count(*)" ) {
      ## order by key to support correct listings
	if ( $arguments{ORDERBY} ) {
		$query .= " ORDER BY " .
			$OpenCA::DBI::SQL->{VARIABLE}->{$arguments{ORDERBY}}[0];
	} else {
      		$query.= " order by ".
             		$OpenCA::DBI::SQL->{VARIABLE}->{$arguments {TABLE}."_ORDERBY"}[0];
	}
  }
  delete $arguments { ORDERBY };

  # Limit the results!!!!
  if ( $items ) {
  	my $hquery = $OpenCA::DBI::DB->{$self->{DB_Type}}->{LIMIT};

	$items = -1 if ( not $items );

  	$hquery =~ s/__QUERY__/$query/;
  	$hquery =~ s/__MAXITEMS__/$items/;
  	$query  = $hquery; 
  }

  my $rv = 0;

  $self->debug_err ( "searchItems: query now: $query",
  		     "searchItems: arguments: @bind_values" );

  #print STDERR "QUERY => $query\n";
  #print STDERR "VALUE => @bind_values\n";

  ## do_query
  $rv = $self->doQuery (QUERY => $query, BIND_VALUES => \@bind_values, BIND_TYPES => \@bind_types);
  if (not defined $rv ) {
  	$self->set_error ( $OpenCA::DBI::ERROR->{SELECT_FAILED} );
  	return undef;
  } else {

    $self->debug ("searchItems: errstr(undef is OK): ".
    						$self->{STH}->errstr());
    $self->debug ("searchItems: rows (this is buggy in DBD::DB2 and " . 
    					"DBD::Oracle)): ".  $self->{STH}->rows);

    ## Results
    ## be warned fetchrow_hashref does not work with DB2
    @retList = ();
    while ( (my $h =  $self->{STH}->fetchrow_arrayref) ) {
	# $counter++;

	$self->debug ("searchItems: item: ".$h->[0]);
	push ( @retList, $h->[0] );
    }

    ## because of searchItemDB + searchItem 
    ## but what it is doing ?
    if( $arguments {MODE} =~ /ROWS|COUNT/i ) {
      $self->debug ("searchItems: leaving function successfully (mode $mode)");
      $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
      return ($retList[0]);
    } elsif ( $arguments{MODE} =~ /KEYLIST/i ) {
      $self->debug ("searchItems: leaving function successfully");
      $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
      return ( @retList );
    }

    for my $i (@retList) {
      my $obj;
	
      	if ( not $obj = $self->getItem( DATATYPE => $arguments{TABLE},
                                        STATUS   => $arguments{STATUS}, 
                                        KEY      => $i )) { 
		$self->debug_err ( "searchItems: error creating object " .
				$arguments{TABLE} . "::" . $arguments{STATUS} .
				"::" . $i);
	}

      $self->debug ("searchItems: add an object to the returnlist");
      push( @objRetList, $obj );
    }

    $self->debug ("searchItems: leaving function successfully");
    $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
    return @objRetList;

  }

  ## never reached
  $self->set_error ( $OpenCA::DBI::ERROR->{UNEXPECTED_ERROR} );
  return undef;

}

## ##################################################################
## Function Name: list Items
## ##################################################################

sub listItems {
   	my $self = shift;
 	return $self->searchItems ( @_ );
}

##################################################
## original unchanged functions from OpenCA::DB ##
##################################################

sub rows {

	## Returns the number of item matching the request. You can search
	## for generic DATATYPE such as CERTIFICATE|REQUEST|CRL
	## or restricted type (EXPIRED_CERTIFICATE|REVOKED_CERTIFICATE|
	## VALID_CERTIFICATE...
	##
	## This function should be used in conjunction with searching function
	## use the elements sub instead if you wish to know how many specific
	## dB elements are there (such as VALID_CERTIFICATES, etc ... )

	my $self = shift;
	my $keys = { @_ };

	return $self->searchItems( MODE=>"ROWS", @_ );
}

## ##################################################################
## Function Name: getSearchAttributes
## ##################################################################

sub getSearchAttributes {

	## new extended function for getSearchAttributes which does not
	## return the index (SERIAL, KEY or DATE)

        my $self = shift;
        my $keys = { @_ };

       $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

        my $type = $keys->{DATATYPE};
        my @ret = ();

        if ( not $type ) {
          $self->set_error ( $OpenCA::DBI::ERROR->{MISSING_ARG_DATATYPE} );
          return undef;
        }

        if ( $type =~ /REQUEST/ ) {
                @ret = ( "KEY", 
                         "STATUS",
                         "DN",
                         "CN",
                         "EMAIL",
                         "RA",
                         "OPERATOR",
                         "ROLE",
                         "PUBKEY",
                         "SCEP_TID",
			 "NOTBEFORE",
			 "NOTAFTER",
			 "APPROVED_AFTER",
			 "ARCHIVED_AFTER",
			 "DELETED_AFTER",
	   		 "ROWID",
                         "LOA" );
        } elsif ( $type =~ /CA_CERTIFICATE/ ) {
                @ret = ( "KEY",
                         "STATUS",
			 "EXPIRES_BEFORE",
			 "EXPIRES_AFTER",
			 "NOTBEFORE",
			 "NOTAFTER",
			 "SUSPENDED_AFTER",
			 "REVOKED_AFTER",
			 "INVALIDITY_REASON",
                         "DN",
                         "CN",
                         "EMAIL",
	   		 "ROWID",
                         "PUBKEY" );
        } elsif ( $type =~ /CERTIFICATE/ ) {
                @ret = ( "KEY",
                         "STATUS",
                         "DN",
                         "CN",
                         "EMAIL",
                         "ROLE",
                         "PUBKEY",
                         "CSR_SERIAL",
			 "EXPIRES_BEFORE",
			 "EXPIRES_AFTER",
			 "NOTBEFORE",
			 "NOTAFTER",
			 "SUSPENDED_AFTER",
			 "REVOKED_AFTER",
			 "INVALIDITY_REASON",
	   		 "ROWID",
                         "LOA" );
        } elsif ( $type =~ /CRR/ ) {
                @ret = ( "KEY",
                         "STATUS",
                         "REVOKE_CERTIFICATE_SERIAL",
                         "REVOKE_CERTIFICATE_DN",
                         "CN",
                         "EMAIL",
                         "RA",
                         "OPERATOR",
                         "SUBMIT_DATE",
                         "REASON",
			 "NOTBEFORE",
			 "NOTAFTER",
			 "APPROVED_AFTER",
			 "ARCHIVED_AFTER",
			 "DELETED_AFTER",
                         "LOA" );
        } elsif ( $type =~ /CRL/ ) {
                @ret = ( "KEY",
                         "STATUS",
			 "EXPIRES_BEFORE",
			 "EXPIRES_AFTER",
                         "LAST_UPDATE",
                         "NEXT_UPDATE" );
	   		 "ROWID",
	} elsif ( $type =~ /^USER$/ ) {
		@ret = ( "USER_ID",
			 "DATA_SOURCE",
			 "SECRET",
			 "NOTBEFORE",
			 "NOTAFTER",
			 "STATUS",
			 "EXTERN_ID",
			 "SUSPENDED_AFTER",
			 "REVOKED_AFTER",
			 "LAST_ACTIVITY",
	   		 "ROWID",
			 "INVALIDITY_REASON" );
	} elsif ( $type =~ /USER_DATA/ ) {
		@ret = ( "USER_ID",
			 "NAME",
	   		 "ROWID",
			 "DATA_SOURCE" );
	} elsif ( $type =~ /MESSAGES/ ) {
		@ret = ( "USER_ID",
	   		 "ROWID",
	   		 "FROM",
	   		 "TO",
	   		 "SUBJECT",
	   		 "NOTBEFORE",
	   		 "HEADER",
	   		 "DATA",
	   		 "STATUS" );
        };

        $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
        return @ret;
}

## ##################################################################
## Function Name: getTimeString
## ##################################################################

sub getTimeString {

	## returns now iso-time

	my $self = shift;
	my  ( $ret, @T );

	@T = gmtime( time() );

        ## iso is yyyy-mm-dd hh:mm:ss
	$ret = sprintf( "%4.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
			 $T[5]+1900, $T[4], $T[3], $T[2], $T[1], $T[0] );

	return $ret;

}

## ##################################################################
## Function Name: getArguments
## ##################################################################

sub getArguments {

  ## parse the arguments for all functions

  my $self = shift;
  my $keys = { @_ };
  my $check;

  my %result;

  if (exists $keys->{DEBUG}) {
      $self->{DEBUG} = $keys->{DEBUG};
      delete $keys->{DEBUG};
  }

  $self->debug ("getArguments: entering function");

  foreach my $key (keys %$keys) {
	if ( $key ne "" ) {
      		$check->{$key} = $keys->{$key};
      		$self->debug ("getArguments: check: $key=".$check->{$key});
	};
  }

  $result {FROM} = $check->{FROM};
  delete $check->{FROM};
 
  $result {ITEMS} = $check->{ITEMS};
  delete $check->{ITEMS};
 
  $result {TABLE} = $self->getTable ($keys->{DATATYPE});
  $result {MODE}  = $keys->{MODE};
  delete $check->{MODE};
  $self->debug ("getArguments: TABLE:".$result {TABLE});
  $self->debug ("getArguments: MODE:".$result {MODE});

  ## get all searchable attributes
  my @attributes = $self->getSearchAttributes( DATATYPE => $result {TABLE} );
  my $attr;

  for $attr ( @attributes ) {
    
    	$self->debug ("getArguments: attribute: $attr");

    	if ($attr =~ /^EMAIL$/ and not $keys->{$attr}) {
        	$result {EMAIL} = $keys->{EMAILADDRESS};
        	delete $check->{EMAILADDRESS};
    	} else {
        	$result {$attr} = $keys->{$attr};
        	delete $check->{$attr};
    	}

    	$self->debug ("getArguments: value: ".$result {$attr});      
  }

  ## enforce status
  $result {STATUS} = $self->getStatus ( STATUS   => $result {STATUS},
                                        DATATYPE => $keys->{DATATYPE} );

  if (not $result {STATUS}) {
    $self->debug ("getArguments: no STATUS present");
    delete ($result {STATUS});
  } else {
    $self->debug ("getArguments: status: ".$result {STATUS});
  }
  delete $check->{STATUS};
  delete $check->{DATATYPE};

  ## New Parameters - used only for CRL and CERTS for now
  delete $check->{EXPIRES_BEFORE};
  delete $check->{EXPIRES_AFTER};
  delete $check->{ROWID};

  ## madwolf -- DEBUG
  if (scalar (keys %$check)) {
      print STDERR "getArguments: ILLEGAL ARGUMENT\n";
      foreach my $key (keys %$check) {
          print STDERR "getArguments: [$key] = [".$check->{$key} . "]\n";
      }
      $self->set_error ( $OpenCA::DBI::ERROR->{ILLEGAL_ARGUMENT} );
      return undef;
  }

  $self->debug ("getArguments: completed successful");
  return %result;

}

## ##################################################################
## Function Name: getTable
## ##################################################################

sub getTable {

  ## this is a standardinterface to get the table from the original
  ## datatype. so we can use the normal interface of OpenCA::DB

  my $self = shift;
  my $datatype = $_[0];
  
  my $ret;
  
  if ( $datatype =~ /CA_CERTIFICATE/ ) {
    $ret = "CA_CERTIFICATE";
  } elsif ( $datatype =~ /CERTIFICATE/ ) {
    $ret = "CERTIFICATE";
  } elsif ( $datatype =~ /CRL/ ) {
    $ret = "CRL";
  } elsif ( $datatype =~ /REQUEST/ ) {
    $ret = "REQUEST";
  } elsif ( $datatype =~ /CRR/ ) {
    $ret = "CRR";
  } else {
    ## Unsupported DATATYPE
    $ret = "";
  }
  
  return $ret;  
}

## ##################################################################
## Function Name: getStatus
## ##################################################################

sub getStatus {

  ## this function support to work with old and new code
  ## this means that I check for STATUS and if it is not existent
  ## I try to extract it from the datatype

  my $self = shift;
  my $keys = { @_ };

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  my $status   = $keys->{STATUS};
  my $datatype = $keys->{DATATYPE};

  $status =~ s/ARCHIVIED/ARCHIVED/;
  $datatype =~ s/ARCHIVIED/ARCHIVED/;

  $self->debug ("getStatus: Entering function");

  if ($status) {
    $self->debug ("getStatus: status predefined: $status");
    ## check for legal status
    if ( $OpenCA::DBI::STATUS->{$status} ) {
      $self->debug ("getStatus: legal status (leaving function)");
      $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
      return $status;
    } else {
      $self->debug ("getStatus: illegal status (leaving function)");
      $self->set_error ( $OpenCA::DBI::ERROR->{ILLEGAL_STATUS} );
      return undef;
    }
  } else {
    $self->debug ("getStatus: no status given using datatype: $datatype");
    ## try to extract status from datatype
    ## erase all behind the first "_" incl. this "_" itself
    my $old = $datatype;
    $datatype =~ s/_.*//g;
    $datatype = $old if ($datatype =~ /^CA$/i);
    $datatype = "" if ($old eq $datatype); 
    $datatype = uc $datatype;
    $self->debug ("getStatus: given mode is now: $datatype");
    ## check for legal status
    if ( $datatype =~ /^$/ )
    {
      $self->debug ("getStatus: no status (leaving function)");
      $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
      return $datatype;
    } elsif ( $OpenCA::DBI::STATUS->{$datatype} ) {
      $self->debug ("getStatus: legal status (leaving function)");
      $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
      return $datatype;
    } else {
      $self->debug ("getStatus: illegal status (leaving function)");
      $self->set_error ( $OpenCA::DBI::ERROR->{ILLEGAL_STATUS} );
      return undef;
    }
  }
}

## ##################################################################
## Function Name: doQuery
## ##################################################################

sub doQuery {
  my $self = shift;
  my $keys = { @_ };

  $self->set_error ( $OpenCA::DBI::ERROR->{DO_NOT_COMMIT} );

  $self->debug ("doQuery: entering function");

  # these variables are in-vars
  my $query     = $keys->{QUERY};
  # my @bind_values = @{$keys->{BIND_VALUES}} if ($keys->{BIND_VALUES});
  my @bind_values = ();
  my @bind_types = @{$keys->{BIND_TYPES}} if ($keys->{BIND_TYPES});

  foreach my $help ( @{$keys->{BIND_VALUES}} ) {
	# if(utf8::is_utf8($help)) {
	# 	  print STDERR "HELP::VALUE is UTF8 => $help\n";
	# 	  utf8::decode($help);
	 #  }
	  push( @bind_values, $help );
  }

  $self->debug ("doQuery: query: $query");

  foreach my $help (@bind_values) {
    ## madwolf -- DEBUG
    $self->debug ("doQuery: bind_values: $help");
  }

  ## query empty so not a DB-failure
  return undef if ($query eq "");

  ## prepare
  $self->debug ("doQuery: prepare statement");
  $self->{STH} = $self->{DBH}->prepare ($query);
  if (not exists $self->{STH} or not defined $self->{STH} or
      						not ref $self->{STH}) {
    	## necessary for Oracle
    	$self->debug ("doQuery: prepare failed");
    	$self->debug ("doQuery: query: $query");
    	$self->debug ("doQuery: prepare returned undef");
    	$self->set_error ( $OpenCA::DBI::ERROR->{PREPARE_FAILED} );
    	return undef;
  }

  ## numer of elements in @bind_values and @bind_types have to be equal 
  if ($#bind_values != $#bind_types) {
    $self->set_error ($OpenCA::DBI::ERROR->{PREPARE_FAILED});
    return undef;
  }

  ## binding values to placeholders 
  my $q_count=0;
  foreach my $q_value (@bind_values)
	{
    $q_count ++;
    my $q_type = shift(@bind_types);

    # if ( $q_type =~ /DECIMAL/ )
		# {

		## If is a number
		if ( $q_value =~ /^-?(?:\d+\.?|\.\d)\d*\z/ )
		{
			if ( $q_type =~ /DECIMAL/ )
			{
       	$self->{STH}->bind_param( $q_count, $q_value, SQL_DECIMAL );
     	}
			elsif ( $q_type =~ /BIGINT/ )
			{
       	$self->{STH}->bind_param( $q_count, $q_value, SQL_BIGINT );
     	}
			else
			{
       	$self->{STH}->bind_param( $q_count, $q_value, SQL_UNKNOWN_TYPE );
			}
		}
		else
		{
			$self->{STH}->bind_param( $q_count, $q_value, SQL_UNKNOWN_TYPE);
		}
  }

  ## execute
  $self->debug ("doQuery: execute statement");

  my $result = $self->{STH}->execute ();
  if (defined $result) {
    $self->debug ("doQuery: execute succeeded (leaving function - $result)");
    $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
    return $result;
  } else {
    # print STDERR "doQuery: query: $query\n";

    $self->debug ("doQuery: execute failed (leaving function)");
    $self->set_error ( $OpenCA::DBI::ERROR->{EXECUTE_FAILED} );
    return undef;
  }
}

## ##################################################################
## Function Name: getResultItem
## ##################################################################

sub getResultItem {

  ## this function is a ready to build an answer from the arguments and
  ## from the resulting array.  Parameters are:
  ##   ARGUMENTS
  ##   ARRAYREF
  
  my $self = shift;
  my $keys = { @_ };
  my %hash = undef;

  my $item;

  $self->debug ("getResultItem: entering function");

  my %arguments = %{$keys->{ARGUMENTS}};
  return undef if (not %arguments);

  my $arrayref = $keys->{ARRAYREF};;
  return undef if (not defined $arrayref);

  $self->debug ("getResultItem: all params present"); 

  %hash = $self->getResultHash (TABLE => $arguments{TABLE},
                                ARRAY => $arrayref);

  # foreach my $i ( keys %hash ) {
  # 	print STDERR "getResultItem: HASH: $i => " . $hash{$i} . "\n";
  # }

  my $data        = $hash{DATA};
  my $priv_format = $hash{FORMAT};
  my $today = gmtime;
  my $now = $self->{backend}->getNumericDate( "$today" );
  my $tempBefore = undef;
  my $tempAfter = undef;

  $self->debug ("getResultItem: data: $data");
  $self->debug ("getResultItem: format: $priv_format");
  $self->debug ("getResultItem: have all data");

  ## If it was asked only the text version, we send out only that
  ## without generating an OBJECT from it
  if( $arguments{MODE} eq "RAW" ) {
    $self->debug ("getResultItem: return data RAW");
    $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
    return $data;
  }
    
  ## Build an Object from retrieved DATA
  if( $arguments{TABLE} =~ /CERTIFICATE/ ) {

    $item = new OpenCA::X509( SHELL      => $self->{backend},
                              GETTEXT    => $self->{gettext},
                              INFORM     => "PEM",
                              DATA       => $data);

    if ( not $item ) {
	#print STDERR "ERROR::" . $arguments{TABLE} .  "::$data\n";
	return undef;
    }

    $item->setStatus( $hash{STATUS} );

    if ( $item->getStatus() =~ /VALID|EXPIRED/ ) {
	$tempBefore = $self->{backend}->getNumericDate( 
				$item->getParsed()->{NOTBEFORE} );
	$tempAfter = $self->{backend}->getNumericDate( 
				$item->getParsed()->{NOTAFTER} );

	if (( $tempBefore <= $now ) and ( $tempAfter >= $now )) {
		$item->setStatus( "VALID" );
	} else {
		# print STDERR "STATUS CHANGE:: BY CHECK => NOW is $now\n";
		# print STDERR "STATUS CHANGE:: NOTBEFORE => " .
		# 		$item->getParsed()->{NOTBEFORE} . "\n";
		# print STDERR "STATUS CHANGE:: NOTAFTER => " .
		# 		$item->getParsed()->{NOTAFTER} . "\n";

		$item->setStatus( "EXPIRED" );
	}
    }

  } elsif ( $arguments{TABLE} eq "CRL" ) {
    $self->debug ("getItem: try to create crl");	
    $item = new OpenCA::CRL( SHELL      => $self->{backend},
                             INFORM     => "PEM",
                             GETTEXT    => $self->{gettext},
                             DATA       => $data);

    $self->debug ("getResultItem: crl there") if ($item);	
    $self->debug ("ResultItem: crl failed") if (not $item);	

    $item->setStatus( $hash{STATUS} );

    if ( $item->getStatus() =~ /VALID|EXPIRED/ ) { 
        $tempBefore = $self->{backend}->getNumericDate( 
				$item->getParsed()->{NOTBEFORE} );
	$tempAfter = $self->{backend}->getNumericDate( 
				$item->getParsed()->{NOTAFTER} );
	if (( $tempBefore <= $now ) and ( $tempAfter >= $now )) {
		$item->setStatus( "VALID" );
	} else {
		$item->setStatus( "EXPIRED" );
	}
    }

  } elsif ( $arguments{TABLE} =~ /(REQUEST|CRR)/i ) {
    $item = new OpenCA::REQ( SHELL      => $self->{backend},
                             GETTEXT    => $self->{gettext},
                             DATA       => $data);

    $item->setStatus( $hash{STATUS} );

  } else {
    ## if we cannot build the object there is probably
    ## an error, retrun a void ...
    $self->debug ("getResultItem: cannot determine table");
    $self->set_error ( $OpenCA::DBI::ERROR->{ WRONG_DATATYPE } );
    return undef;
  }
  if (not $item)
  {
    $self->debug ("getResultItem: cannot build object return void");
    $self->set_error ( $OpenCA::DBI::ERROR->{ CANNOT_CREATE_OBJECT } );
    return undef;
  }

  # $item->{STATUS} = $hash{STATUS};

  ## who uses DBKEY ?!
  $item->{parsedItem}->{DBKEY} = $arguments{KEY};
  $item->{parsedItem}->{KEY} = $arguments{KEY};
  $item->{KEY} = $arguments{KEY};

  $item->{parsedItem}->{ROWID} = $hash { ROWID };
  $item->{ROWID} = $hash { ROWID };

  $item->{DATATYPE} = $hash{STATUS} . "_" . $arguments{TABLE};

  ## We return the object
  $self->debug ("getResultItem: return item");
  $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );

  return $item;
      
} ## end of getResultItem

## ##################################################################
## Function Name: getResultHash
## ##################################################################

sub getResultHash {

	## this function is neccessary because DB2 does not support
	## the function fetchrow_hashref

	my $self = shift;
	my $keys = { @_ };
	my @cols = ();
	my %result;

	$self->debug ("getResultHash: entring function");
	@cols = @{$OpenCA::DBI::SQL->{TABLE_STRUCTURE}->{$keys->{TABLE}}};

	for (my $i = 0; $i <= $#cols; $i++) {
		my $val = undef;

		$val = $keys->{ARRAY}->[$i];
		if ( ($val ne "" ) and (! utf8::is_utf8( $val )) ) {
		 	utf8::decode($val);
		}

		$result { $cols[$i]} = $val;

		# print STDERR "getResultHash: " . $keys->{TABLE} . ": " .
		# 	"HASH{" . $cols[$i] . "} = ".$keys->{ARRAY}->[$i]."\n";

		$self->debug ("getResultHash: column: ".  $cols[$i]);
		$self->debug ("getResultHash: value: ".$keys->{ARRAY}->[$i]);
  }

  $self->debug ("getResultHash: leaving function");

  return %result;
  
}

## ##################################################################
## BEGIN BLOCK: DB Management: rollback, commit, disconnect, DESTROY
## ##################################################################

sub rollback {

  ## rollback never touch the status because 
  ## rollback is normally the action if a
  ## statement fails

  my $self = shift;

  $self->debug ("rollback: entering function");

  ## if there is no databasehandle then we have not to and cannot roll back
  if (not $self->{DBH} or $self->{DBH}->rollback()) {
    $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} )
        if (not $self->errno());
    return 1;
  } else {
    $self->set_error ( $OpenCA::DBI::ERROR->{ROLLBACK_FAILED} );
    return undef;
  }
}

## Function: commit
## ================

sub commit {

  ## commit sets the status-variable
  my $self = shift;

  $self->debug ("commit: entering function");

  if (not defined $self->{DBH} or $self->{DBH}->commit())
	{
    $self->set_error ($OpenCA::DBI::ERROR->{SUCCESS}) if (not $self->errno());
    return 1;
  }
	else
	{
		print STDERR "DEBUG::commit failure.\n";
		print STDERR $self->traceme();

    $self->set_error ( $OpenCA::DBI::ERROR->{COMMIT_FAILED} );
    return undef;
  }

	return(1);
}

## Function: disconnect
## ====================
## disconnect does not set the status-variable because commit
## and rollback called before disconnect so success is not important

sub disconnect {
  
  my $self = shift;

  ## Added to correctly handle the disconnection
  if (defined $self->{STH})
	{
  	$self->{STH}->finish();
  };

  if ( (exists $self->{DBH}) and ($self->{DBH}->disconnect()))
	{
    $self->set_error ( $OpenCA::DBI::ERROR->{SUCCESS} );
    return 1;
  }
	else
	{
    $self->set_error ( $OpenCA::DBI::ERROR->{DISCONNECT_FAILED} );
    return undef;
  }

	return 1;
}

## Function: DESTROY
## =================

sub DESTROY 
{
  my $self = shift;

  if ($self->{ERRNO} != $OpenCA::DBI::ERROR->{SUCCESS})
	{
    $self->debug ("DESTROY: automatic rollback by destructor DESTROY");
    $self->rollback ();
  }
	else
	{
    $self->debug ("DESTROY: automatic commit by destructor DESTROY");

    if (not $self->commit())
		{

			print STDERR "OpenCA::DBI::DESTROY()->Auto Commit FAILED!\n";
			$self->debug_err ( "WARNING: commit failed when destroying db handler",
      			   "WARNING: rollback() called.");
			$self->rollback ();
    }
  }

  ## finish the statement handles to reduce warnings by DBI
  $self->debug ("DESTROY: call finish on all statement handles to avoid warnings by DBI");

  $self->{STH}->finish() if (exists $self->{STH});
  $self->{DBH}->disconnect () if (exists $self->{DBH});
}

## ##################################################################
## BEGIN BLOCK: Error Handling 
## ##################################################################

sub errno
{
  my $self = shift;
  
  if ( exists $self->{errno} ) {
    $self->debug ("errno: returning local errorcode ".$self->{errno});
    return $self->{errno};
  } else {
    $self->debug ("errno: returning global errorcode $OpenCA::DBI::errno");
    return $OpenCA::DBI::errno;
  }
}

sub set_error {
  my $self = shift;

  $self->debug ("Entering set_error ...");

  ## checking for an explicit error message (from DBI)

  my $message = $OpenCA::DBI::MESSAGE->{$_[0]};
  $message = $_[1] if ($_[1]);

  ## if gettext was not defined
  ## then fall back to conventional errormessages

  if (not $self->{gettext})
  {
    $self->debug ("set_error: gettext is not defined");

    if (defined $_[0])
    {
      $self->{errno}  = $_[0];
      $self->{errval} = $message;
    }
    $self->debug ("set_error: errno and errval set");
  } else
  {
    ## fully i18n error handling

    $self->debug ("errno: gettext is defined");
    $message = $self->{gettext} ($message);

    ## set errorcode
    my $old = $self->{errno};
    $self->{errno} = $_[0];

    ## this is the new OpenCA-standard
    if ($old)
    {
      $self->debug ("errno: old errno $old is present");

      ## save the last error too
      $self->{errval} = $self->{gettext} ("__MESSAGE__ (error __OLD_ERRNO__: __OLD_ERRVAL__)",
                                  "__MESSAGE__", $message,
                                  "__OLD_ERRNO__", $old,
                                  "__OLD_ERRVAL__", $self->{errval});
    } else {
      $self->{errval} = $self->{gettext} ($message);
    }

    $self->debug ("errno: new errorcode is $errno");
  }
  $errno  = $self->{errno};
  $errval = $self->{errval};

  return undef;
}

sub errval {
  my $self = shift;
  my $text = "";
  my $code;

  return $self->{errval} if ($self->{errval});
  return $errval;
}

sub debug {
    my $self = shift;
    # my @call = caller ( 1 );

    # if ($_[0]) {
    #     $self->{debug_msg}[scalar @{$self->{debug_msg}}] = $_[0];
    #     $self->debug () if ($self->{DEBUG});
    # } else {
    #     my $msg;
    #     if ( $self->{DEBUG_STDERR} ) {
		# 			foreach $msg (@{$self->{debug_msg}}) {
		# 				print STDERR "OpenCA::DBI->$msg\n";
		# 			}
		# 		}
    #     $self->{debug_msg} = ();
    # }

		if ($self->{DEBUG})
		{
			if ($_[0])
			{
				$self->{debug_msg}[scalar @{$self->{debug_msg}}] = $_[0];
				$self->debug ();
			}
			else
			{
				my $msg;
				if ($self->{DEBUG_STDERR})
				{
					foreach $msg (@{$self->{debug_msg}})
					{
						print STDERR "OpenCA::DBI->$msg\n";
					}
				}
				$self->{debug_msg} = ();
			}
		}
}

sub debug_err 
{
	my $self = shift;

	if ( $self->{DEBUG_STDERR} )
	{
   	foreach my $msg ( @_ ) 
		{
       	print STDERR "OpenCA::DBI->$msg\n";
		}
		print STDERR $self->traceme(1);
  }
}

sub traceme 
{
	my $self = shift;
	my $level = shift;
	my $end = 0;
  my $ret = "";
	my @c = undef;

	if ($level > 0)
	{
		$end = $level;
	}

  my @me = caller($end + 1);

  $ret = "traceme(" . $me[3] . ")->Start.\n";
  for (my $i = 10; $i > $end; $i--)
  {
    @c = caller ($i);
    next if ($#c < 1);

    $ret .= "[$i] traceme(" . $me[3] . "): " . $c[3] . "() at " . $c[1] . ":" . $c[2];
    if ($i == $end+1)
    {
      $ret .= "    [*** this is me ***]";
    }
    $ret .= "\n";
  }
  $ret .= "traceme(" . $me[3] . ")->End.\n";

  return $ret;
}

##########################
## end of new functions ##
##########################

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

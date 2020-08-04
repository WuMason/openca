# openca
openca build

Tools:

  1.openssl 1.0.2k
  2.httpd-2.2.32
  3.openca-tools-1.3.1
  4.openca-base.1.5.1
  
  you also need mysql bdb openldap perl

Server:
  Ubuntu 12.04

Setup:
1.openssl
  ./config shared --prefix=/home/Mason/work/openssl
  make && make install
  mv /usr/bin/openssl /usr/bin/openssl.bak
  ln -s /home/Mason/work/openssl/bin/openssl /usr/bin/openssl 
  Now,your opepnssl version is 1.0.2k
  
2.apache

  ./configure --prefix=/home/Mason/work/httpd-2.2.32 --enable-mods-shared=most --with-mpm-MPM=worker --enable-ssl --with-ssl=/home/Mason/work/openssl
  make && make install
  
3.openca-tools-1.3.1

  ./configure --prefix=/home/Mason/work/openca-tools
  make & make install
  
4.openca-base.1.5.1

  ./configure  --prefix="/home/Mason/work/openca-base" --with-openca-tools-prefix=/home/Mason/work/openca-tools --with-openssl-prefix=/home/neldtv/work/openssl --with-ca-organization=Mason --with-db-name=xx --with-db-host=xx.xx.xx.xx --with-db-user=root --with-db-passwd="openca" --with-db-type=mysql --with-web-host=localhost --with-httpd-fs-prefix=/home/Mason/work/httpd-2.2.32 --with-htdocs-fs-prefix=/home/Mason/work/httpd-2.2.32/htdocs/pki --with-module-prefix=/home/Mason/work/openca-base/modules -with-httpd-user=daemon --with-httpd-group=daemon
  make 
  make install-offline(install CA)
  make install-online (install RA and PUB)
  cd /home/Mason/work/openca-base/etc/openca && ./configure_etc.sh
  
Now, you can open openca !

  /home/Mason/work/openca-base/etc/init.d/openca start 
  
The first time you need to enter a password !

You also need close apche2 and start your apache ..

   service apache2 stop
   /home/Mason/work/httpd-2.2.32/bin/apachectl restart
   
Finally , enter IP/pki in google,you can find your openca
  
  
  
  

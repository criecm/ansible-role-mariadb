# MariaDB

Setup mariadb (with galera cluster if wanted) on FreeBSD host

Using `include_role/tasks_from: db.yml` creates a single db+user

## Role Variables (default value)
* `mariadb_admin_user`: (admin)
* `mariadb_admin_password`: ''
  You *need* to set this one
* `mariadb_root_password`: ''
  Local access only / remote disabled
* `mariadb_socket`: (/tmp/mysql.sock)
* `mariadb_version`: (10.5)
  Version to install if not already installed (or to upgrade to if `do_upgrade_mariadb==True`)
* `mariadb_basedir`: (/var/db/mysql)
* `mariadb_logdir`: (/var/log/mysql)
* `mariadb_owner`: (mysql)
* `mariadb_group`: (mysql)
* `mariadb_use_syslog`: (True)
  Use system's syslog instead of log files
* `mariadb_zfs_base`: ('')
  if any, will create/set recordsize to 16K and create innodb-logs subdir (128K)
* `mariadb_users`: ([])
  Users to be created, dict with keys 'priv','name','password' and 'host'
  password won't be updated, only set at creation
  ( like in [mysql_user module](http://docs.ansible.com/ansible/latest/mysql_user_module.html "mysql_user module") )
* `mariadb_maintenance_users`: ([])
  like above, but to be defined globally
* `mariadb_dbs`: ([])
  List of databases to create (dict with keys 'name')
* `mariadb_config: ({})`
  Dict of config directives to be inserted in server ini file

### galera specific
* `galera` dict:
*   `cluster_name`: your cluster name
*   `nodes`: list of dicts containing:
      `name` (short hostname)
      `address` (ip or hostname)
      `is_backup` if true, will only serve requests when master is failed (for haproxy)
    ¡ First node will be master !
*   `clustercheck`: dict with `user` and `pass` for haproxy check responder
*   `galeracheck`: dict with `user` and `pass` for garb autolauncher
*   `local_haproxy`: (False)
    Replace mysqld on port 3306 with haproxy, change mariadb port to 3305 (or `galera.myport`)

## one-shot (CLI) variables
* `mariadb_relayout_zfs` (False)
  If defined (on command-line!), will change data layout for ZFS use
* `do_upgrade_mariadb` (False)
  If defined (CLI), upgrade mariadb packages to wanted/latest version
* `init_galera_cluster_now` (False)
  If defined, a NEW galera cluster will be initialized (breaking any existing cluster)

## Example Playbooks

    # install / create db's from `mariadb_dbs` and users from `mariadb_users` and `mariadb_maintenance_users`
    - hosts: servers
      roles:
         - { role: criecm.mariadb, mariadb_admin_password: '42', mariadb_zfs_base: 'zdata/mariadb' }

    # just create a single database (the main task have already been run on the host(s))
    - hosts: dbservers
      include_role:
        name: criecm.mariadb
	tasks_from: db.yml
      vars:
        mariadb: { name: mydatabase, user: myuser, pass: hispass, fromhost: mywebsrv.my.domain, priv: 'mydatabase.*:ALL' }
      # you'll find a generated password in `db_pass` fact if not provided

    # Galera cluster
    - hosts: mycluster # needs to be a group
      vars:            # store these in group_vars !
        galera:
	  cluster_name: mycluster
	  nodes:
	    - { name: myserver1, address: 192.0.2.1 }
	    - { name: myserver2, address: 192.0.2.2 }
	    - { name: myserver3, address: 192.0.2.3 }
	  clustercheck:
            user: clustercheck
            pass: 'Choose a unique password here'
          galeracheck:
            user: galeracheck
            pass: 'Choose a(nother) unique password here'

## License

BSD

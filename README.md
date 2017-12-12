MariaDB
=======

Install/setup mariadb on FreeBSD

Requirements
------------
None

## Role Variables (default value)

* `mariadb_admin_user`: (admin)
* `mariadb_admin_password`: ''
  You *need* to set this one
* `mariadb_root_password`: ''
  Local access only / remote disabled
* `mariadb_version`: (10.2)
* `mariadb_basedir`: (/var/db/mysql)
* `mariadb_logdir`: (/var/log/mysql)
* `mariadb_owner`: (mysql)
* `mariadb_group`: (mysql)
* `mariadb_zfs_base`: ('')
  if any, will create/set recordsize to 16K
* `mariadb_users`: ([])
  Users to be created, dict with keys 'priv','name','password' and 'host'
  ( like in http://docs.ansible.com/ansible/latest/mysql_user_module.html )
* `mariadb_maintenance_users`: ([])
  like above, but to be defined globally
* `mariadb_dbs`: ([])
  List of databases to create (dict with keys 'name')

Dependencies
------------

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: criecm.mariadb, mariadb_default_password: '42', mariadb_zfs_base: 'zdata/mariadb' }

License
-------

BSD


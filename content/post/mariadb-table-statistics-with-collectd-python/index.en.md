---
type: post
title: MariaDB Table statistics with collectd-python
date: 2015-08-12
tags:
- MariaDB
- Python
- collectd
- metrics
keywords:
- MariaDB
- Python
- collectd
- metrics
---

[MariaDB][0] is an open source fork of MySQL initiated by its original author Michael "Monty" Widenius. It is a drop-in replacement of the famous open source RDBMS – enhancing it with some very nice [features and performance improvements][1].

MariaDB is virtually compatible with almost all third-party tools and utilities of the MySQL ecosystem, including monitoring tools. My dear go-to metrics collecting tool [collectd][2] has a native [MySQL plugin][3] that is also compatible, although MariaDB can expose more metrics than MySQL – and than the collectd plugin is aware of. Case in point: the [user statistics][4], introduced in MariaDB 5.2.0.

These statistics provide various fine-grained metrics on user activity and tables/indexes usage. Being especially interested in table statistics to know which tables are the most queried/modified, I decided to poll these metrics using collectd's [Python module][5]. This module executes Python code within a collectd process, avoiding the overhead of spawning a full-fledged Python interpreter every N seconds for instance using collectd's [exec][6] plugin.

Here is my attempt at such a Python module:

{{< gist "falzm" "89db743f2fb7318c286f" >}}

Requirements:

* MariaDB user statistics enabled
* collectd compiled with Python module   
* MySQL [Python connector][7]

Limitations:

* the module expects the MariaDB server to be listening on the local host on the port 3306
* polls the `ROWS_READ`/`ROWS_CHANGED` metrics from the `TABLE_STATISTICS` only
* not tested with Python 3

Copy the script in a location known to your system's Python interpreter:

```shell
$ python -c 'import sys; print sys.path'
['', '/usr/lib/python2.7', '/usr/lib/python2.7/plat-linux2', '/usr/lib/python2.7/lib-tk', '/usr/lib/python2.7/lib-old', '/usr/lib/python2.7/lib-dynload', '/usr/local/lib/python2.7/dist-packages', '/usr/lib/python2.7/dist-packages', '/usr/lib/pymodules/python2.7']
```

Note: it is also possible to configure collectd using the [ModulePath][8] directive to call the script from another location outside of Python's standard paths.

Here is the corresponding collectd configuration to use it:

```text
<Plugin python>
  LogTraces true
  Interactive false
  Import "collectd_mariadb_tablestats"

  <Module collectd_mariadb_tablestats>
    mariadb_login "<DB login>"
    mariadb_password "<DB password>"
    mariadb_ignore_schemas "mysql"
    mariadb_ignore_tables "not_this_table" "not_this_ones_either_*"
  </Module>
</Plugin>
```

Note: the `Import` directive **must** have the same name as the Python script – without the *.py* extension –, e.g. `Import "collectd_mariadb_tablestats"` if the script is at `/usr/local/lib/python2.7/dist-packages/collectd_mariadb_tablestats.py`.

The module is configurable via a `Module` directive within the `Python` module block, that **must** have the same name as the Python script – without the *.py* extension:

* `mariadb_login`: login of the user to log into the database server
* `mariadb_password`: password of the user to log into the database server
* `mariadb_ignore_schemas`: list of [Unix shell-style wildcards][9] for ignoring certain schemas (databases) from the results
* `mariadb_ignore_tables`: list of [Unix shell-style wildcards][9] for ignoring certain tables from the results

Here is an example of the collected metrics displayed in [Facette](https://facette.io/):

{{< postimg file="collectd_mariadb_tablestats.png" width="800" >}}

[0]: https://mariadb.org/
[1]: https://mariadb.com/kb/en/mariadb/mariadb-vs-mysql-features/
[2]: https://collectd.org/
[3]: https://collectd.org/wiki/index.php/Plugin:MySQL
[4]: https://mariadb.com/kb/en/mariadb/user-statistics/
[5]: https://collectd.org/documentation/manpages/collectd-python.5.shtml
[6]: https://collectd.org/documentation/manpages/collectd-exec.5.shtml
[7]: http://dev.mysql.com/doc/connector-python/en/index.html
[8]: https://collectd.org/documentation/manpages/collectd-python.5.shtml#modulepath_name
[9]: https://docs.python.org/2/library/fnmatch.html

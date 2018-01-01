---
type: post
title: rTorrent Statistics with collectd
date: 2014-07-14
tags:
- collectd
keywords:
- collectd
- metrics
- torrent
---

I'm kind of crazy for metrics and monitoring, and I was looking for an opportunity to have some new graphs to look at.

As a long-time [rTorrent](http://rakshasa.github.io/rtorrent/) user — well, exclusively for downloading and sharing my favorites Linux distros *of course* —, I like its console-based interface but I have to admit that its statistics reporting is a bit... raw. I know there are some nice web-based clients for rTorrent out there, but I just wanted to display some metrics in a fancy way.

**Disclaimer**: this is just a proof-of-concept, I did it for fun and it's not intended to be neither [very] useful nor reliable.

## Requirements

In order to pull this off, here are the components involved:

* rTorrent with SCGI support
* [collectd](http://collectd.org/) >= 5.2 compiled the with `curl_xml` plugin
* Nginx (works with [lighttpd](https://github.com/rakshasa/rtorrent/wiki/RPC-Setup-XMLRPC#for-lighttpd), should be feasible with Apache too)
 
## rTorrent configuration

First things first, we have to configure rtorrent to expose a SCGI interface so we can query it for the metrics we want. In the `.rtorrent.rc` configuration file, add the following line:

```conf
scgi_port = 127.0.0.1:4000
```
    
...then restart `rorrent`. Quick tip to check if the configuration is correct:

```shell
$ echo -ne '26:CONTENT_LENGTH\x00109\x00SCGI\x001\x00,<?xml version="1.0" encoding="UTF-8"?><methodCall><methodName>system.client_version</methodName></methodCall>' | nc 127.0.0.1 4000
Status: 200 OK
Content-Type: text/xml
Content-Length: 152

<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
<params>
<param><value><string>0.9.2</string></value></param>
</params>
</methodResponse>
```

## Nginx configuration

Here is the Nginx virtual host configuration to act as gateway between the rTorrent SCGI interface and collectd's `curl_xml` plugin (adapted from [RPC Setup XMLRPC](https://github.com/rakshasa/rtorrent/wiki/RPC-Setup-XMLRPC)):

```conf
server {
  listen 127.0.0.1:4001;

  location / {
    scgi_pass 127.0.0.1:4000;
    include scgi_params;
    scgi_param SCRIPT_NAME /RPC2;
  }
}
```

Reload your `nginx` instance; again, here is quick check to see if everything works as expected before going further:

```shell
$ curl --data '<?xml version="1.0" encoding="UTF-8"?><methodCall><methodName>system.client_version</methodName></methodCall>' http://127.0.0.1:4001
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
<params>
<param><value><string>0.9.2</string></value></param>
</params>
</methodResponse>
```

## collectd configuration

```conf
LoadPlugin curl_xml

<Plugin "curl_xml">
  <URL "http://127.0.0.1:4001">
    Instance "rtorrent"
      Header "Content-Type: application/x-www-form-urlencoded"
      Post "<?xml version=\"1.0\" encoding=\"UTF-8\"?><methodCall><methodName>system.multicall</methodName><params><param><value><array><data><value><struct><member><name>methodName</name><value><string>get_down_rate</string></value></member><member><name>params</name><value><array><data><value><string/></value></data></array></value></member></struct></value><value><struct><member><name>methodName</name><value><string>get_up_rate</string></value></member><member><name>params</name><value><array><data><value><string/></value></data></array></value></member></struct></value></data></array></value></param></params></methodCall>"

    <XPath "/methodResponse/params/param/value/array/data/value[1]">
      Type "bytes"
      InstancePrefix "download"
        ValuesFrom "array/data/value/i8"
    </XPath>
    <XPath "/methodResponse/params/param/value/array/data/value[2]">
      Type "bytes"
      InstancePrefix "upload"
        ValuesFrom "array/data/value/i8"
    </XPath>
  </URL>
</Plugin>
```
    
Restart your `collectd` process, then *ta-daaaa!* The result in [Facette](https://facette.io/):

{{< postimg file="rtorrent_facette.png" width="800" >}}

## Going further

If you found this article interesting and want to dig deeper, here are some useful resources:

* rtorrent [XML-RPC reference](https://code.google.com/p/gi-torrent/wiki/rTorrent_XMLRPC_reference)
* collectd [curl_xml plugin documentation](https://collectd.org/documentation/manpages/collectd.conf.5.shtml#plugin_curl_xml)

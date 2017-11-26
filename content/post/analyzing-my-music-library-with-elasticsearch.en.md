---
type: post
title: Analyzing My Music Library with Elasticsearch
date: 2015-10-04
tags:
- Elasticsearch
- Python
- iTunes
keywords:
- Elasticsearch
- Python
- iTunes
---

I listen to music *a lot*. Looking at my iTunes music library the other day, I started making "smart" playlists to classify my music collection per year of albums releases. It's been a tedious process – and I only went back from 2015 to 1991. Then I realized that the process of classifying and analyzing my music collection could actually be an interesting activity, and I started wondering about how to do it efficiently. Having only used [Elasticsearch][0] at work for trivial logs indexing and searching so far, I figured I could use it in a more "advanced" way to help my dig through my gigabytes of music tracks.

## Indexing iTunes library into Elasticsearch

In order to search through my music library I first had to extract the tracks metadata from iTunes and index them in Elasticsearch.

The first step was quite simple: extract the library from iTunes in a file `library.xml` – iTunes menu *File > Library > Export Library*. The result is a [XML Property Lists][1] file that I had to convert into JSON documents indexable by Elasticsearch. A raw library track entry looks like this:

```xml
<key>1566</key>
<dict>
    <key>Track ID</key><integer>1566</integer>
    <key>Name</key><string>Gravity</string>
    <key>Artist</key><string>A Perfect Circle</string>
    <key>Composer</key><string>Maynard James Keenan, Billy Howerdel, Josh Freese, Troy Van Leeuwen, Paz Lenchantin</string>
    <key>Album</key><string>Thirteenth Step</string>
    <key>Genre</key><string>Rock</string>
    <key>Kind</key><string>MPEG audio file</string>
    <key>Size</key><integer>12286195</integer>
    <key>Total Time</key><integer>306128</integer>
    <key>Disc Number</key><integer>1</integer>
    <key>Disc Count</key><integer>1</integer>
    <key>Track Number</key><integer>12</integer>
    <key>Track Count</key><integer>12</integer>
    <key>Year</key><integer>2003</integer>
    <key>Date Modified</key><date>2009-11-14T11:46:42Z</date>
    <key>Date Added</key><date>2013-04-15T21:12:53Z</date>
    <key>Bit Rate</key><integer>320</integer>
    <key>Sample Rate</key><integer>44100</integer>
    <key>Play Count</key><integer>4</integer>
    <key>Play Date</key><integer>3488975157</integer>
    <key>Play Date UTC</key><date>2014-07-23T13:45:57Z</date>
    <key>Normalization</key><integer>2325</integer>
    <key>Artwork Count</key><integer>1</integer>
    <key>Sort Artist</key><string>Perfect Circle</string>
    <key>Persistent ID</key><string>D9E761709EA898D1</string>
    <key>Track Type</key><string>File</string>
    <key>Location</key><string>file:///Users/marc/Music/A%20Perfect%20Circle/Thirteenth%20Step/12%20Gravity.mp3</string>
    <key>File Folder Count</key><integer>4</integer>
    <key>Library Folder Count</key><integer>1</integer>
</dict>
```

I've written a quick'n dirty Python script that parses this file in a trivial and sub-optimal way – especially if like me the exported library file is several megabytes long:

<script src="https://gist.github.com/falzm/8036d7838aef560c80cd.js"></script>

As you can see, it only keeps a few fields from the library tracks metadata – the ones I've found relevant to my analysis.

Running the script passing the exported library file as argument generates a `library.json` file containing as many JSON-formatted lines as there are tracks in the library:

```shell
$ ./itunes2json.py library.xml > library.json

$ wc -l library.json
8408 library.json

$ head -n 1 library.json
{"album": "Fight Club", "total_time": 303, "kind": "MPEG audio file", "name": "Who Is Tyler Durden ?", "artist": "The Dust Brothers", "play_count": 2, "bit_rate": 320, "year": "1999", "genre": "Soundtrack", "size": 12239773}
```

The more efficient way I've found to index the JSON documents into Elasticsearch is to use its [Bulk API][2]. This method requires a bit of shell scripting to bulk the records:

```shell
$ while read track; do
  echo '{"index":{"_index":"library","_type":"track"}}'
  echo $track
done < library.json > bulk
```

The *library* Elasticsearch index settings and mapping for the "track" document type looks like this:

```shell
$ cat library.index
{
  "settings" : {
    "index" : {
      "number_of_shards" : 1,
      "number_of_replicas" : 0
    }
  },
  "mappings": {
    "track": {
      "properties": {
        "year": { "format": "year", "type": "date" },
        "album": { "index": "not_analyzed", "type": "string" },
        "artist": { "index": "not_analyzed", "type": "string" },
        "genre": { "index": "not_analyzed", "type": "string" },
        "kind": { "index": "not_analyzed", "type": "string" },
        "name": { "index": "not_analyzed", "type": "string" },
        "play_count": { "type": "long" },
        "total_time": { "type": "long" },
        "bit_rate": { "type": "long" },
        "size": { "type": "long"
        }
      }
    }
  }
}

# Create the index
$ curl -X PUT -d @library.index localhost:9200/library
{"acknowledged":true}

# Bulk load the documents
$ curl --data-binary @bulk localhost:9200/library/track/_bulk?pretty
...
    "create" : {
      "_index" : "library",
      "_type" : "track",
      "_id" : "AVAqUo18SEui9dB0w9wD",
      "_version" : 1,
      "status" : 201
    }
  } ]
}

$ curl localhost:9200/library/_stats/docs/?pretty
{
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "failed" : 0
  },
  "_all" : {
    "primaries" : {
      "docs" : {
        "count" : 8392,
        "deleted" : 0
      }
    },
    "total" : {
      "docs" : {
        "count" : 8392,
        "deleted" : 0
      }
    }
  },
  "indices" : {
    "library" : {
      "primaries" : {
        "docs" : {
          "count" : 8392,
          "deleted" : 0
        }
      },
      "total" : {
        "docs" : {
          "count" : 8392,
          "deleted" : 0
        }
      }
    }
  }
}
```

You might have noticed than I ended up with fewer documents indexed than expected (8392 instead of 8408): during the bulk indexing some encoding errors occurred, causing Elasticsearch to discard some documents. For instance:

```shell
...
    "create" : {
      "_index" : "library",
      "_type" : "track",
      "_id" : "AVAqUo1zSEui9dB0w9g8",
      "status" : 400,
      "error" : "MapperParsingException[failed to parse]; nested: JsonParseException[Unexpected character ('D' (code 68)): was expecting comma to separate OBJECT entries\n at [Source: [B@afbf6; line: 1, column: 100]]; "
    }
...
```

Oh well... Let's move to the fun part ;)

## Analyzing my music collection

First, but that goes without saying: the results obtained are only as good as my music files' metadata, e.g. the ID3 tags for MP3 files. I tried my best to keep them clean and exact, but there might be some inconsistencies here and there.

I've used Kibana for the first part of my analysis. When looking up at our indexed documents without any specific query, here is what we can find:

<img src="/img/post/analyzing-my-music-library-with-elasticsearch/Screen-Shot-2015-10-04-at-15-19-36.png" width="800">

I started with a few visualization widgets summarizing trivial stats on my collection:

### Top 10 artists/bands

<img src="/img/post/analyzing-my-music-library-with-elasticsearch/Screen-Shot-2015-10-02-at-23-30-24.png" width="800">

That one was quite a surprise to me: although I used to listen to a lot of Final Fantasy soundtracks, I didn't expect [Nobuo Uematsu][3] to be the most represented artist in my collection.

### Distribution per year

<img src="/img/post/analyzing-my-music-library-with-elasticsearch/Screen-Shot-2015-10-04-at-15-22-57.png" width="800">

Not much to say here: I tend to listen to fairly recent music.

### Top 10 musical genres

<img src="/img/post/analyzing-my-music-library-with-elasticsearch/Screen-Shot-2015-10-04-at-15-24-24.png" width="800">

For what it's worth when trying to classify music into strict genres, the trend is quite clear here: I listen mostly to (movie, video games) soundtracks, Rock and Metal.

### File kinds

<img src="/img/post/analyzing-my-music-library-with-elasticsearch/Screen-Shot-2015-10-02-at-23-50-43.png" width="800">

Nothing special to say about this either: my music collection is essentially composed of MP3 ripped from original CD, and a few tracks bought in the Apple iTunes store.

OK, time to level up a bit. The next queries have been made directly via Elasticsearch's [search API][4] – usually leveraging [aggregations][7] –, as I haven't been able to find how to do it using Kibana.

### 10 Most played tracks

```shell
$ curl 'localhost:9200/library/track/_search?q=*&sort=play_count:desc&fields=artist,name,album,play_count&size=10&pretty'
```
([Raw query result](https://gist.github.com/falzm/0e0c39c21d21db6f8cd8))

<table border="1">
  <tr>
    <th>Artist/band</th>
    <th>Track Name</th>
    <th>Album</th>
    <th># played</th>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>Nomadic</td>
    <td>.5: The Gray Chapter</td>
    <td>143</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>Goodbye</td>
    <td>.5: The Gray Chapter</td>
    <td>122</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>The One That Kills The Least</td>
    <td>.5: The Gray Chapter</td>
    <td>116</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>Lech</td>
    <td>.5: The Gray Chapter</td>
    <td>99</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>Killpop</td>
    <td>.5: The Gray Chapter</td>
    <td>93</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>AOV</td>
    <td>.5: The Gray Chapter</td>
    <td>90</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>The Devil In I</td>
    <td>.5: The Gray Chapter</td>
    <td>90</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>Skeptic</td>
    <td>.5: The Gray Chapter</td>
    <td>81</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>Sarcastrophe</td>
    <td>.5: The Gray Chapter</td>
    <td>80</td>
  </tr>
  <tr>
    <td>Asking Alexandria</td>
    <td>Dear Insanity</td>
    <td>Reckless And Relentless</td>
    <td>68</td>
  </tr>
</table>

Well, I *love* this Slipknot album...

### Top 10 most albums per artist/band

This query ranks artists/bands by the number of albums – that I own, of course:

```shell
$ curl -d '{
  "query": {
    "query_string": { "query": "*", "analyze_wildcard": true }
  },
  "aggregations": {
    "per_artist": {
      "terms": {
        "field": "artist",
        "size": 10,
        "order": { "artist_albums.value": "desc" }
      },
      "aggregations": {
        "artist_albums": {
          "cardinality": {
            "field": "album"
          }
        }
      }
    }
  }
}' 'localhost:9200/library/track/_search?search_type=count&pretty'
```
([Raw query result](https://gist.github.com/falzm/0c0d6d8454b8c57ac4c8"))

<table border="1">
  <tr>
    <th>Artist/band</th>
    <th># albums</th>
  </tr>
  <tr>
    <td>Thrice</td>
    <td>14</td>
  </tr>
  <tr>
    <td>Muse</td>
    <td>12</td>
  </tr>
  <tr>
    <td>Nine Inch Nails</td>
    <td>9</td>
  </tr>
  <tr>
    <td>The Used</td>
    <td>9</td>
  </tr>
  <tr>
    <td>Avenged Sevenfold</td>
    <td>8</td>
  </tr>
  <tr>
    <td>EZ3kiel</td>
    <td>8</td>
  </tr>
  <tr>
    <td>Nobuo Uematsu</td>
    <td>8</td>
  </tr>
  <tr>
    <td>Disturbed</td>
    <td>7</td>
  </tr>
  <tr>
    <td>Feeder</td>
    <td>7</td>
  </tr>
  <tr>
    <td>Foo Fighters</td>
    <td>7</td>
  </tr>
</table>

### Shortest/Longest track duration

Shortest track:

```shell
$ curl 'localhost:9200/library/track/_search?q=*&sort=total_time:asc&fields=artist,name,album,total_time&size=1&pretty'
```
([Raw query result](https://gist.github.com/falzm/f6eb329105b896e78d39))

<table border="1">
  <tr>
    <th>Artist/band</th>
    <th>Track Name</th>
    <th>Album</th>
    <th>Track duration</th>
  </tr>
  <tr>
    <td>Enhancer</td>
    <td>Glock II</td>
    <td>Street Trash</td>
    <td>5s</td>
  </tr>
</table>

Longest track:

```shell
$ curl 'localhost:9200/library/track/_search?q=*&sort=total_time:desc&fields=artist,name,album,total_time&size=1&pretty'
```
([Raw query result](https://gist.github.com/falzm/6cdc22118754eee488d6))

<table border="1">
  <tr>
    <th>Artist/band</th>
    <th>Track Name</th>
    <th>Album</th>
    <th>Track duration</th>
  </tr>
  <tr>
    <td>Hans Zimmer</td>
    <td>Alabama</td>
    <td>Crimson Tide Movie Soundtrack</td>
    <td>23m50s</td>
  </tr>
</table>

### Longest single album duration

```shell
curl -d '{
  "query": {
    "query_string": { "query": "*", "analyze_wildcard": true }
  },
  "aggregations": {
    "per_artist": {
      "terms": { "field": "artist", "size": 1 },
      "aggregations": {
        "per_album": {
          "terms": { "field": "album", "size": 1 },
          "aggregations": {
            "album_duration": {
              "sum": { "field": "total_time" }
            }
          }
        }
      }
    }
  }
}' 'localhost:9200/library/track/_search?search_type=count&pretty'
```
([Raw query result](https://gist.github.com/falzm/c0fbba78a135595ecee3))

<table border="1">
  <tr>
    <th>Artist/band</th>
    <th>Album</th>
    <th>Album duration</th>
  </tr>
  <tr>
    <td>Nobuo Uematsu</td>
    <td>Final Fantasy VIII Soundtrack</td>
    <td>4h8m52s</td>
  </tr>
</table>

Finding this one has been a bit problematic: I've found the correct result, but the method is flawed.

The method should have been:

 1. Aggregate tracks per artist
 1. Sub-aggregate the aggregated tracks per artist per album
 1. Sub-aggregate the aggregated tracks per artist per album by summing their `total_time` field
 1. Sort the results by the `total_time` summed value of each artist album

I've managed to do all that except the final sorting, because Elasticsearch is only able to perform ["deep" metrics sorting][5] on nested sub-aggregations when all nested buckets on the path to sorting metric are single-valued, and this is not the case here. The only reason I've got the correct result in my case is because there is completely unrelated to the aggregation results: by default Elasticsearch [sorts results by the number of documents per aggregated bucket][6], and it happens that the longest album in duration is by an artist/band that *also* features the most indexed documents in my collection. The problem can be observed when looking beyond the first result, for instance with a top 10 of the longest albums:

```shell
curl -d '{
  "query": {
    "query_string": { "query": "*", "analyze_wildcard": true }
  },
  "aggregations": {
    "per_artist": {
      "terms": { "field": "artist", "size": 10 },
      "aggregations": {
        "per_album": {
          "terms": { "field": "album", "size": 1 },
          "aggregations": {
            "album_duration": {
              "sum": { "field": "total_time" }
            }
          }
        }
      }
    }
  }
}' 'localhost:9200/library/track/_search?search_type=count&pretty'
```
([Raw query result](https://gist.github.com/falzm/72be66843abe03c10971))

<table border="1">
  <tr>
    <th>Artist/band</th>
    <th>Album</th>
    <th>Album duration</th>
    <th># total artist/band tracks indexed</th>
  </tr>
  <tr>
    <td>Nobuo Uematsu</td>
    <td>Final Fantasy VIII Original Soundtrack</td>
    <td>4h8m52s</td>
    <td>166</td>
  </tr>
  <tr>
    <td>Nine Inch Nails</td>
    <td>Ghosts I-IV</td>
    <td>1h50m9s</td>
    <td>156</td>
  </tr>
  <tr>
    <td>Muse</td>
    <td>B-sides (grouping of all B-sides)</td>
    <td>1h34m23s</td>
    <td>147</td>
  </tr>
  <tr>
    <td>Thrice</td>
    <td>Anthology</td>
    <td>1h43m7s</td>
    <td>143</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>Slipknot</td>
    <td>1h18m46s</td>
    <td>113</td>
  </tr>
  <tr>
    <td>The Used</td>
    <td>Shallow Believer</td>
    <td>1h7m28s</td>
    <td>113</td>
  </tr>
  <tr>
    <td>Disturbed</td>
    <td>The Sickness</td>
    <td>1h9m19s</td>
    <td>102</td>
  </tr>
  <tr>
    <td>Foo Fighters</td>
    <td>In Your Honor</td>
    <td>1h23m16s</td>
    <td>95</td>
  </tr>
  <tr>
    <td>Korn</td>
    <td>Issues</td>
    <td>53m9s</td>
    <td>95</td>
  </tr>
  <tr>
    <td>EZ3kiel</td>
    <td>LUX</td>
    <td>1h10m18s</td>
    <td>94</td>
  </tr>
</table>

Then I figured out a simpler way – incidentally providing correct results – but I had to let go the "artist/band:album" relation:

```shell
$ curl -d '{
  "query": {
    "query_string": { "query": "*", "analyze_wildcard": true }
  },

  "aggregations": {
    "per_album": {
      "terms": {
        "field": "album",
        "size": 10,
        "order": { "album_duration.value": "desc" }
      },
      "aggregations": {
        "album_duration": {
          "sum": { "field": "total_time" }
        }
      }
    }
  }
}' 'localhost:9200/library/track/_search?search_type=count&pretty'
```
([Raw query result](https://gist.github.com/falzm/bac88b2bb43192d7e2cd))

<table border="1">
  <tr>
    <th>Album</th>
    <th>Album duration</th>
  </tr>
  <tr>
    <td>Final Fantasy VIII Original Soundtrack</td>
    <td>4h8m52s</td>
  </tr>
  <tr>
    <td>The Girl With The Dragon Tattoo (Movie Soundtrack)</td>
    <td>2h53m34s</td>
  </tr>
  <tr>
    <td>Chopin: Essential Classic</td>
    <td>2h38m30s</td>
  </tr>
  <tr>
    <td>The Dark Knight (Movie Soundtrack)</td>
    <td>2h26m16s</td>
  </tr>
  <tr>
    <td>Mad Max: Fury Road (Movie Soundtrack)</td>
    <td>2h5m8s</td>
  </tr>
  <tr>
    <td>The Amazing Spider-Man 2 (Movie Soundtrack)</td>
    <td>1h55m6s</td>
  </tr>
  <tr>
    <td>The Incredible Hulk (Movie Soundtrack)</td>
    <td>1h51m</td>
  </tr>
  <tr>
    <td>Ghosts I-IV</td>
    <td>1h50m9s</td>
  </tr>
  <tr>
    <td>Chopin - 19 Nocturnes</td>
    <td>1h46m58s</td>
  </tr>
  <tr>
    <td>The Fragile</td>
    <td>1h43m39s</td>
  </tr>
</table>

### Largest single album in tracks number

```shell
$ curl -d '{
  "query": {
    "query_string": { "query": "*", "analyze_wildcard": true }
  },
  "aggregations": {
    "per_album": {
      "terms": { "field": "album", "size": 1 }
    }
  }
}' 'localhost:9200/library/track/_search?search_type=count&pretty'
```
([Raw query result](https://gist.github.com/falzm/14a709f46f6acbac68d1))

<table border="1">
  <tr>
    <th>Artist/band</th>
    <th>Album</th>
    <th># tracks</th>
  </tr>
  <tr>
    <td>Nobuo Uematsu</td>
    <td>Final Fantasy VIII Soundtrack</td>
    <td>74</td>
  </tr>
</table>

### Top 10 longest combined music duration per artist/band

```shell
$ curl -d '{
  "query": {
    "query_string": { "query": "*", "analyze_wildcard": true }
  },
  "aggregations": {
    "per_album": {
      "terms": { "field": "album", "size": 1 }
    }
  }
}' 'localhost:9200/library/track/_search?search_type=count&pretty'
```
([Raw query result](https://gist.github.com/falzm/98e315c02d9af2738007))

<table border="1">
  <tr>
    <th>Artist/band</th>
    <th>Total duration</th>
  </tr>
  <tr>
    <td>Nine Inch Nails</td>
    <td>10h47m38s</td>
  </tr>
  <tr>
    <td>Muse</td>
    <td>10h32m13s</td>
  </tr>
  <tr>
    <td>Nobuo Uematsu</td>
    <td>10h0m1s</td>
  </tr>
  <tr>
    <td>Thrice</td>
    <td>9h12m59s</td>
  </tr>
  <tr>
    <td>EZ3kiel</td>
    <td>8h2m56s</td>
  </tr>
  <tr>
    <td>Slipknot</td>
    <td>7h51m44s</td>
  </tr>
  <tr>
    <td>The Used</td>
    <td>6h57m28s</td>
  </tr>
  <tr>
    <td>Disturbed</td>
    <td>6h52m19s</td>
  </tr>
  <tr>
    <td>Korn</td>
    <td>6h44m36s</td>
  </tr>
</table>

## Conclusion

This exercise allowed me to extract interesting facts and trends about my tastes from my own music collection, and got me to know Elasticsearch a little better in the process. It's been a fun ride :)

[0]: https://www.elastic.co/products/elasticsearch
[1]: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/PropertyLists/UnderstandXMLPlist/UnderstandXMLPlist.html
[2]: https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html
[3]: https://en.wikipedia.org/wiki/Nobuo_Uematsu
[4]: https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations.html
[5]: https://www.elastic.co/guide/en/elasticsearch/guide/current/_sorting_based_on_deep_metrics.html
[6]: https://www.elastic.co/guide/en/elasticsearch/guide/current/_sorting_multivalue_buckets.html
[7]: https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations.html

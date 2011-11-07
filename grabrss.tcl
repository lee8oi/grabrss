
################################################################################
# Copyright ©2011 lee8oi@gmail.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# http://www.gnu.org/licenses/
#
################################################################################
#
# This is a versatile tcl script that can fetch RSS feed data and keep a 'latest news'
# cache as well as a database for old news. You can: grab items by index. List items by
# feed. Fetch feeds. Refresh all feeds. Add/remove feeds. search, backup db to file,
# restore db from file, etc.
# 
# To use: open tclsh. Do 'source grabrss.tcl'. Then use 'refresh' to update all feeds.
# commands available: iget, iadd, flist, fadd, fdel, search, listfeed, ctrim, fetch,
# dbackup, drestore, cflush, htmldecode, unhtml.
#  *c=cache f=feed d=database i=item (news item)
#
# Todo:
# 1.allow item and feed deletion (stored data).
# 2.allow item creation.
#
#:::::::::::::::::::::::::::Configuration:::::::::::::::::::::::::::::::::::::::
#
# maxcache: How many news items should each feed have in cache at a time?
# ctrim trims cache down to this number and puts trimmings in db.
#                      +---+
variable maxcache	20
#                      +---+
#
# feeds: set feeds here. One per set.
#                 +------------------------------------------------------------+
set feeds(google) "http://news.google.com/news?ned=us&topic=h&output=rss"
set feeds(linuxtoday) "http://feeds.feedburner.com/linuxtoday/linux?format=xml"
set feeds(pclinuxos) "http://pclinuxos.com/?feed=rss2"
set feeds(securitynow) "http://leoville.tv/podcasts/sn.xml"
set feeds(krotkie) "http://www.joemonster.org/backend.php?channel=krotkie"
set feeds(pclosforum) "http://www.pclinuxos.com/forum/index.php?board=15.0;type=rss;action=.xml;limit=50"
#                 +------------------------------------------------------------+
#
################################################################################
#!!!!!!!!!!!!!!!!!!!Experts Only Below!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
################################################################################
package require http
if {![catch {package require tls}]} { ::http::register https 443 ::tls::socket }

proc grab {} {
	#:just a quick command for sourcing the script file:::::::::::::::::::::
	source "grabrss.tcl"
}

proc help {args} {
	print help "grabrss commands available: iget iadd fadd fdel flist listfeed search\
	ctrim cflush fetch dbackup drestore unhtml htmldecode"
	print help "run command without args for more information on it."
}

proc print {{type ""} {msg ""}} {
	#:print msg to output:::::::::::::::::::::::::::::::::::::::::::::::::::
	if {($type == "") || ($msg == "")} {print help "~print a msg to output. usage: print <type> <msg>"; return}
	switch "$type" {
		"puts" {
			puts $msg
		}
		"help" {
			puts "~help: $msg"
		}
	}
}

proc refresh {args} {
	#:refresh feeds:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	variable feeds
	foreach feed [array names feeds] {
		fetch $feed; ctrim $feed
	}
	print puts "~feeds refreshed."
}

proc flist {args} {
	#:get list of feeds available:::::::::::::::::::::::::::::::::::::::::::
	variable feeds; set result ""
	foreach item [array names feeds] {
		append result "$item "
	}
	print puts "~available feeds: $result"
}

proc fadd {{feed ""} {url ""}} {
	#:add a feed to the feeds list::::::::::::::::::::::::::::::::::::::::::
	if {($feed == "") || ($url == "")} {print help "add an rss feed to feeds list. usage: fadd <feedname> <url>"; return}
	variable feeds; variable cacheindex
	if {![info exists feeds($feed)]} {
		set feeds($feed) $url
		if {![info exists cacheindex($feed)]} {set cacheindex($feed) 1}
		print puts "~$feed feed added."
	} else {
		print puts "~use a different name."
	}
}

proc fdel {{feed ""}} {
	#:remove a feed from the feedss list::::::::::::::::::::::::::::::::::::
	if {($feed == "")} {print help "delete an rss feed from feeds list. usage: fdel <feed> <url>"; return}
	variable feeds
	if {[info exists feeds($feed)]} {
		unset feeds($feed)
		print puts "~$feed feed deleted."
	} else {
		print puts "~feed doesn't exist."
	}
}

proc drestore {} {
	#:restore news from db::::::::::::::::::::::::::::::::::::::::::::::::::
	if {[file exists "grabrss.db"]} {
		source "grabrss.db"
		print puts "~backup restored."
	}
}

proc dbackup {} {
	#:backup db to file:::::::::::::::::::::::::::::::::::::::::::::::::::::
	variable dblinks; variable dbtitles; variable dbdescs; variable dbindex
	cflush
	set fs [open "grabrss.db" w+]
	foreach arr {dbtitles dblinks dbdescs dbindex} {
		puts $fs "variable $arr"
		puts $fs "array set $arr [list [array get [set arr]]]"
	}
	close $fs;
	print puts "~backup performed."
}

proc iget {{src ""} {feed ""} {index ""}} {
	#:output news item stored in cache at <feed> <index>::::::::::::::::::::
	if {($feed == "") || ($index == "") || ($src == "")} {print help "get item from src(db or cache) in feed at index. usage: iget <source> <feed> <index>"; return}
	switch "$src" {
		"db" {
			variable dblinks; variable dbtitles; variable dbindex; variable dbdescs
			array set tmplinks [array get dblinks]; array set tmptitles [array get dbtitles]
			array set tmpindex [array get dbindex]; array set tmpdescs [array get dbdescs]
		}
		"cache" {
			variable cachetitles; variable cachelinks; variable cachedescs; variable cacheindex
			array set tmplinks [array get cachelinks]; array set tmptitles [array get cachetitles]
			 array set tmpdescs [array get cachedescs]; array set tmpindex [array get cacheindex];
		}
		default {
			print puts "specify a valid src. Options: db or cache."
			return
		}
	}
	if {[info exists tmptitles($feed,$index)]} {
		print puts "Title ~ $tmptitles($feed,$index)"
		print puts "Link ~ $tmplinks($feed,$index)"
		set desc [htmldecode $tmpdescs($feed,$index)]
		print puts "Description ~ $desc"
	} else {
		print puts "cannot find that news item."
	}
}

proc iadd {{feed ""} {title ""} {link ""} {desc ""}} {
	#:add news item to cache::::::::::::::::::::::::::::::::::::::::::::::::
	if {($title == "") || ($link == "") || ($desc == "")} {print help "add news item to cache in feed. usage:\
		iadd <feed> <title> <link> <desc>"; return}
	variable source; variable cachetitles; variable cachelinks; variable cachedescs
	variable cacheindex
	if {![info exists cacheindex($feed)]} {set cacheindex($feed) 1}
	#if {![info exists cacheindex($feed)]} {print puts "~iadd~ feed doesn't exist."; return}
	set ismatch 0
	#:check if title already exists:::::::::::::::::::::::::::::::::::::::::
	foreach item [array names cachetitles] {
		#:check cache titles::::::::::::::::::::::::::::
		if {($cachetitles($item) == $title)} {
			set ismatch 1
		}
	}
	foreach item [array names dbtitles] {
		#:check database titles:::::::::::::::::::::::::
		if {($dbtitles($item) == $title)} {
			set ismatch 1
		}
	}
	#:add news if no match found::::::::::::::::::::::::::::
	if {$ismatch == 0} {
		set cachetitles($feed,$cacheindex($feed)) $title
		set cachelinks($feed,$cacheindex($feed)) $link
		set cachedescs($feed,$cacheindex($feed)) $desc
		print puts "~Breaking News~ $feed ~ $cachetitles($feed,$cacheindex($feed)) ~ $cachelinks($feed,$cacheindex($feed))"
		incr cacheindex($feed)
	}
}

proc cflush {} {
	#:flush cache to db:::::::::::::::::::::::::::::::::::::::::::::::::::::
	variable dbindex; variable dbtitles; variable dblinks; variable dbdescs
	variable cachetitles; variable cachelinks; variable cachedescs; variable cacheindex
	set cachesize [array size cachetitles]
	set count 0
	foreach item [array names cacheindex] {
		set cindex 1
		while {($cindex <= $cachesize)} {
			set ismatch 0
			if {![info exists cachetitles($item,$cindex)]} {break}
			foreach dbitem [array names dbtitles] {
				#:check database titles:::::::::::::::::::::::::
				if {($dbtitles($dbitem) == $cachetitles($item,$cindex))} {
					set ismatch 1
					break
				}
			}
			if {($ismatch == 0)} {
				#:move item from cache to db:::::::::::::::::::::::::::
				set dbtitles($item,$dbindex($item)) $cachetitles($item,$cindex)
				set dblinks($item,$dbindex($item)) $cachelinks($item,$cindex)
				set dbdescs($item,$dbindex($item)) $cachedescs($item,$cindex)
				incr dbindex($item)
				incr count
			}
			incr cindex
		}
	}
	if {($count > 0)} {
		print puts "~cache~flushed $count items to db."
	}
}

proc search {{src ""} {field ""} {term ""}} {
	#:search for items containing term:::::::::::::::::::::::::::::::
	if {($term == "") || ($field == "") || ($src == "")} {print help "search by field(title,link,desc,all) in \
		src(db,cache,all) for news items containing term. usage: search <source> <field> <term>"; return}
	switch "$src" {
		"db" {
			variable dblinks; variable dbtitles; variable dbindex; variable dbdescs
			array set tmplinks [array get dblinks]; array set tmptitles [array get dbtitles]
			array set tmpindex [array get dbindex]; array set tmpdescs [array get dbdescs]
		}
		"cache" {
			variable cachetitles; variable cachelinks; variable cachedescs; variable cacheindex
			array set tmplinks [array get cachelinks]; array set tmptitles [array get cachetitles]
			 array set tmpdescs [array get cachedescs]; array set tmpindex [array get cacheindex];
		}
		"all" {
			search "db" $field $term
			search "cache" $field $term
			return
		}
		default {
			print puts "specify a valid src. Options: db or cache."
			return
		}
	}
	set count 0
	switch "$field" {
		"title" {
			foreach item [array names tmptitles] {
				if {[string match -nocase "*${term}*" $tmptitles($item)]} {
					incr count
					print puts "~$src~title~ match $count: $tmptitles($item) ~ $tmplinks($item)"
				}
			}
		}
		"link" {
			foreach item [array names tmplinks] {
				if {[string match -nocase "*${term}*" $tmplinks($item)]} {
					incr count
					print puts "~$src~link~ match $count: $tmplinks($item) ~ $tmplinks($item)"
				}
			}
		}
		"desc" {
			foreach item [array names tmpdescs] {
				if {[string match -nocase "*${term}*" $tmpdescs($item)]} {
					incr count
					print puts "~$src~desc~ match $count: $tmpdescs($item) ~ $tmpdescs($item)"
				}
			}
		}
		"all" {
			search $src "title" $term
			search $src "link" $term
			search $src "desc" $term
			return
		}
		default {
			print puts "invalid field option. use: title link desc or all."
		}
	}
}

proc listfeed {{src ""} {feed ""}} {
	#:list feed elements from cache or db:::::::::::::::::::::::::::::::::::
	if {($feed == "") || ($src == "")} {print help "list items in feed from src(db,cache,all). usage: listfeed <source> <feed>"; return}
	switch "$src" {
		"db" {
			variable dblinks; variable dbtitles; #variable dbindex; variable dbdescs
			array set tmplinks [array get dblinks]; array set tmptitles [array get dbtitles]
			#array set tmpindex [array get dbindex]; array set tmpdescs [array get dbdescs]
		}
		"cache" {
			variable cachetitles; variable cachelinks; #variable cachedescs; variable cacheindex
			array set tmplinks [array get cachelinks]; array set tmptitles [array get cachetitles]
			 #array set tmpdescs [array get cachedescs]; array set tmpindex [array get cacheindex];
		}
		"all" {
			listfeed "db" $feed
			listfeed "cache" $feed
			return
		}
		default {
			print puts "specify a valid src. Options: db, cache, or all."
			return
		}
	}
	variable maxcache; variable feeds
	set count 1
	if {[string match -nocase "all" $feed]} {
		foreach item [array names feeds] {
			set contin 1; set count 1
			while {($count > 0)} {
				if {[info exists tmptitles($item,$count)]} {
					print puts "~$src~$item,$count ~ $tmptitles($item,$count) ~ $tmplinks($item,$count)"
					incr count
				} else {
					set contin 0
				}
			}
		}
	} else {
		set contin 1; set count 1
		while {($contin > 0)} {
			if {[info exists tmptitles($feed,$count)]} {
				print puts "~$src~$feed,$count ~ $tmptitles($feed,$count) ~ $tmplinks($feed,$count)"
				incr count
			} else {
				set contin 0
			}
		}
	}
}

proc ctrim {{feed ""}} {
	#:trim cache to maxcache::::::::::::::::::::::::::::::::::::::::::::::::
	if {($feed == "")} {print help "trim feed to 'maxcache' size and store trimmed items in database. usage: ctrim <feed>"; return}
	variable dbindex; variable dbtitles; variable dblinks; variable dbdescs
	variable cachetitles; variable cachelinks; variable cachedescs; variable cacheindex
	variable maxcache
	if {![info exists cachetitles($feed,1)]} {return}
	if {![info exists dbindex($feed)]} {set dbindex($feed) 1}
	set count 0
	foreach item [array names cachetitles "$feed*"] {
		incr count
	}
	if {($count > $maxcache)} {
		set cindex 1
		while {$count > $maxcache} {
			#:move oldest items from cache to db::::::::::::::::::::
			if {![info exists cachetitles($feed,$cindex)]} {break}
			set dbtitles($feed,$dbindex($feed)) $cachetitles($feed,$cindex)
			set dblinks($feed,$dbindex($feed)) $cachelinks($feed,$cindex)
			set dbdescs($feed,$dbindex($feed)) $cachedescs($feed,$cindex)
			incr dbindex($feed)
			incr cindex
			incr count -1
		}
		set nindex 1
		while {($nindex <= $count)} {
			#:reorder cache from 1.Unset old variables::::::::::::::
			set cachetitles($feed,$nindex) $cachetitles($feed,$cindex)
			unset cachetitles($feed,$cindex)
			set cachelinks($feed,$nindex) $cachelinks($feed,$cindex)
			unset cachelinks($feed,$cindex)
			set cachedescs($feed,$nindex) $cachedescs($feed,$cindex)
			unset cachedescs($feed,$cindex)
			incr nindex; incr cindex; set cacheindex($feed) $nindex
		}
	}
}

proc fetch {{feed ""}} {
	#:fetch feed data and save news to cache::::::::::::::::::::::::::::::::
	if {($feed == "")} {print help "fetch rss data from web and add new news to cache. usage: fetch <feed>"; return}
	variable feeds
	if {[info exists feeds($feed)]} {set url $feeds($feed)} else {puts "invalid feed. check 'flist'?"; return}
	set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"
	set http [::http::config -useragent $ua]
	catch {set http [::http::geturl $url -timeout 60000]} error
	if {[info exists http]} {
		if { [::http::status $http] == "timeout" } {
			puts "Oops timed out."
			return 0
		}
		upvar #0 $http state
		array set meta $state(meta)
		set url $state(url)
		set data [::http::data $http]
		#:handle redirects::::::::::::::::::::::::::::::::::::::::::::::
		foreach {name value} $state(meta) {
			if {[regexp -nocase ^location$ $name]} {
				set mapvar [list " " "%20"]
				::http::cleanup $http
				catch {set http [::http::geturl $value -timeout 60000]} error
				if {![string match -nocase "::http::*" $error]} {
					return "http error: [string totitle $error] \( $value \)"
				}
				if {![string equal -nocase [::http::status $http] "ok"]} {
					return "status: [::http::status $http]"
				}
				set url [string map {" " "%20"} $value]
				upvar #0 $http state
				if {[incr r] > 10} { puts "redirect error (>10 too deep) \( $url \)" ; return 0}
				set data [::http::data $http]
			}
		}
		::http::cleanup $http
		set data [htmldecode $data] ;#:markup code cleanup::::::::::::::
		if {[regexp {(?i)<title>(.*?)</title>} $data -> foo]} {
			append source($feed) $foo
		}
		if {[regexp {(?i)<description>(.*?)</description>} $data -> foo]} {
			append source($feed) " | $foo"
		}
		#:loop through data.grab new news:::::::::::::::::::::::::::::::
		regsub -all {(?i)<items.*?>.*?</items>} $data {} data
		foreach {foo item} [regexp -all -inline {(?i)<item.*?>(.*?)</item>} $data] {
			set item [string map {"<![CDATA[" "" "]]>" ""} $item]
			regexp {<title.*?>(.*?)</title>}  $item subt title
			regexp {<link.*?>(.*?)</link}     $item subl link
			regexp {<desc.*?>(.*?)</desc.*?>} $item subd descr
			#:html tag cleanup::::::::::::::::::::::::::::::::::::::
			if {![info exists title]} {set title "(none)"} {set title [unhtml [join [split $title]]]}
			if {![info exists link]}  {set link  "(none)"} {set link [unhtml [join [split $link]]]}
			if {![info exists descr]} {set descr "(none)"} {set descr [unhtml [join [split $descr]]]}
			iadd $feed $title $link $descr
		}
		return
	} else {
		#:no http data::::::::::::::::::::::::::::::::::::::::::::::::::
		return
	}
}

proc unhtml {{data ""}} {
	#:remove html tags from data.borrowed from webby::::::::::::::::::::::::
	if {($data == "")} {print puts "remove html tags from data. usage: unhtml <data>"; return}
	regsub -all "(?:<b>|</b>|<b />|<em>|</em>|<strong>|</strong>)" $data"\002" data
	regsub -all "(?:<u>|</u>|<u />)" $data "\037" data
	regsub -all "(?:<br>|<br/>|<br />)" $data ". " data
	regsub -all "<script.*?>.*?</script>" $data "" data
	regsub -all "<style.*?>.*?</style>" $data "" data
	regsub -all -- {<.*?>} $data " " data
	while {[string match "*  *" $data]} { regsub -all "  " $data " " data }
	return [string trim $data]
}

proc htmldecode {{data ""}} {
	#:cleanup html markups.borrowed from webby::::::::::::::::::::::::::::::
	if {($data == "")} {print help "remove html markup codes from data. usage: htmldecode <data>"; return}
	if {![string match *&* $data]} {return $data}
	set escapes {
               &nbsp; \xa0 &iexcl; \xa1 &cent; \xa2 &pound; \xa3 &curren; \xa4
               &yen; \xa5 &brvbar; \xa6 &sect; \xa7 &uml; \xa8 &copy; \xa9
               &ordf; \xaa &laquo; \xab &not; \xac &shy; \xad &reg; \xae
               &macr; \xaf &deg; \xb0 &plusmn; \xb1 &sup2; \xb2 &sup3; \xb3
               &acute; \xb4 &micro; \xb5 &para; \xb6 &middot; \xb7 &cedil; \xb8
               &sup1; \xb9 &ordm; \xba &raquo; \xbb &frac14; \xbc &frac12; \xbd
               &frac34; \xbe &iquest; \xbf &Agrave; \xc0 &Aacute; \xc1 &Acirc; \xc2
               &Atilde; \xc3 &Auml; \xc4 &Aring; \xc5 &AElig; \xc6 &Ccedil; \xc7
               &Egrave; \xc8 &Eacute; \xc9 &Ecirc; \xca &Euml; \xcb &Igrave; \xcc
               &Iacute; \xcd &Icirc; \xce &Iuml; \xcf &ETH; \xd0 &Ntilde; \xd1
               &Ograve; \xd2 &Oacute; \xd3 &Ocirc; \xd4 &Otilde; \xd5 &Ouml; \xd6
               &times; \xd7 &Oslash; \xd8 &Ugrave; \xd9 &Uacute; \xda &Ucirc; \xdb
               &Uuml; \xdc &Yacute; \xdd &THORN; \xde &szlig; \xdf &agrave; \xe0
               &aacute; \xe1 &acirc; \xe2 &atilde; \xe3 &auml; \xe4 &aring; \xe5
               &aelig; \xe6 &ccedil; \xe7 &egrave; \xe8 &eacute; \xe9 &ecirc; \xea
               &euml; \xeb &igrave; \xec &iacute; \xed &icirc; \xee &iuml; \xef
               &eth; \xf0 &ntilde; \xf1 &ograve; \xf2 &oacute; \xf3 &ocirc; \xf4
               &otilde; \xf5 &ouml; \xf6 &divide; \xf7 &oslash; \xf8 &ugrave; \xf9
               &uacute; \xfa &ucirc; \xfb &uuml; \xfc &yacute; \xfd &thorn; \xfe
               &yuml; \xff &fnof; \u192 &Alpha; \u391 &Beta; \u392 &Gamma; \u393 &Delta; \u394
               &Epsilon; \u395 &Zeta; \u396 &Eta; \u397 &Theta; \u398 &Iota; \u399
               &Kappa; \u39A &Lambda; \u39B &Mu; \u39C &Nu; \u39D &Xi; \u39E
               &Omicron; \u39F &Pi; \u3A0 &Rho; \u3A1 &Sigma; \u3A3 &Tau; \u3A4
               &Upsilon; \u3A5 &Phi; \u3A6 &Chi; \u3A7 &Psi; \u3A8 &Omega; \u3A9
               &alpha; \u3B1 &beta; \u3B2 &gamma; \u3B3 &delta; \u3B4 &epsilon; \u3B5
               &zeta; \u3B6 &eta; \u3B7 &theta; \u3B8 &iota; \u3B9 &kappa; \u3BA
               &lambda; \u3BB &mu; \u3BC &nu; \u3BD &xi; \u3BE &omicron; \u3BF
               &pi; \u3C0 &rho; \u3C1 &sigmaf; \u3C2 &sigma; \u3C3 &tau; \u3C4
               &upsilon; \u3C5 &phi; \u3C6 &chi; \u3C7 &psi; \u3C8 &omega; \u3C9
               &thetasym; \u3D1 &upsih; \u3D2 &piv; \u3D6 &bull; \u2022
               &hellip; \u2026 &prime; \u2032 &Prime; \u2033 &oline; \u203E
               &frasl; \u2044 &weierp; \u2118 &image; \u2111 &real; \u211C
               &trade; \u2122 &alefsym; \u2135 &larr; \u2190 &uarr; \u2191
               &rarr; \u2192 &darr; \u2193 &harr; \u2194 &crarr; \u21B5
               &lArr; \u21D0 &uArr; \u21D1 &rArr; \u21D2 &dArr; \u21D3 &hArr; \u21D4
               &forall; \u2200 &part; \u2202 &exist; \u2203 &empty; \u2205
               &nabla; \u2207 &isin; \u2208 &notin; \u2209 &ni; \u220B &prod; \u220F
               &sum; \u2211 &minus; \u2212 &lowast; \u2217 &radic; \u221A
               &prop; \u221D &infin; \u221E &ang; \u2220 &and; \u2227 &or; \u2228
               &cap; \u2229 &cup; \u222A &int; \u222B &there4; \u2234 &sim; \u223C
               &cong; \u2245 &asymp; \u2248 &ne; \u2260 &equiv; \u2261 &le; \u2264
               &ge; \u2265 &sub; \u2282 &sup; \u2283 &nsub; \u2284 &sube; \u2286
               &supe; \u2287 &oplus; \u2295 &otimes; \u2297 &perp; \u22A5
               &sdot; \u22C5 &lceil; \u2308 &rceil; \u2309 &lfloor; \u230A
               &rfloor; \u230B &lang; \u2329 &rang; \u232A &loz; \u25CA
               &spades; \u2660 &clubs; \u2663 &hearts; \u2665 &diams; \u2666
               &quot; \x22 &amp; \x26 &lt; \x3C &gt; \x3E O&Elig; \u152 &oelig; \u153
               &Scaron; \u160 &scaron; \u161 &Yuml; \u178 &circ; \u2C6
               &tilde; \u2DC &ensp; \u2002 &emsp; \u2003 &thinsp; \u2009
               &zwnj; \u200C &zwj; \u200D &lrm; \u200E &rlm; \u200F &ndash; \u2013
               &mdash; \u2014 &lsquo; \u2018 &rsquo; \u2019 &sbquo; \u201A
               &ldquo; \u201C &rdquo; \u201D &bdquo; \u201E &dagger; \u2020
               &Dagger; \u2021 &permil; \u2030 &lsaquo; \u2039 &rsaquo; \u203A
               &euro; \u20AC &apos; \u0027 &lrm; "" &rlm; "" &#8236; "" &#8237; ""
               &#8238; "" &#8212; \u2014
	};
	#:clean up markup codes,etc:::::::::::::::::::::::::::::::::::::::::::::
	set data [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\\" "\\\\"] [string map $escapes $data]]
	set data [string map {"&raquo;" "»" "&nbsp;" " "} $data] ;#escapes map misses these.fixme.
	regsub -all -- {&#([[:digit:]]{1,5});} $data {[format %c [string trimleft "\1" "0"]]} data
	regsub -all -- {&#x([[:xdigit:]]{1,4});} $data {[format %c [scan "\1" %x]]} data
	regsub -all -- {\\x([[:xdigit:]]{1,2})} $data {[format %c [scan "\1" %x]]} data
	set data [subst "$data"]
	return $data
}
print puts "grabrss by lee8oi - loaded"
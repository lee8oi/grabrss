
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
# To use: open tclsh. 'source grabrss.tcl' then 'refresh'. then refresh every so
# often to update the feeds. use 'dget <feed> <index>' to grab specific news
# item.
#
################################################################################

package require http
package require tls
::http::register https 443 ::tls::socket
variable maxcache 10
set feeds(google) "http://news.google.com/news?ned=us&topic=h&output=rss"
set feeds(linuxtoday) "http://feeds.feedburner.com/linuxtoday/linux?format=xml"
set feeds(pclinuxos) "http://pclinuxos.com/?feed=rss2"
set feeds(securitynow) "http://leoville.tv/podcasts/sn.xml"
set feeds(krotkie) "http://www.joemonster.org/backend.php?channel=krotkie"
set feeds(pclosforum) "http://www.pclinuxos.com/forum/index.php?board=15.0;type=rss;action=.xml;limit=50"

proc refresh {} {
	#:refresh feeds:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	variable feeds
	foreach feed [array names feeds] {
		fetch_data $feed $feeds($feed)
		trim_cache $feed
	}
}
proc fetch_data {feed url} {
	#:fetch feed data and save news to cache::::::::::::::::::::::::::::::::
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
		variable source; variable cachetitles; variable cachelinks; variable cachedescs
		variable cacheindex
		if {![info exists cacheindex($feed)]} {set cacheindex($feed) 1}
		set data [descdecode $data] ;#:markup code cleanup::::::::::::::
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
			#:check if title already exists:::::::::::::::::::::::::
			set ismatch 0
			foreach item [array names cachetitles] {
				if {($cachetitles($item) == $title)} {
					set ismatch 1
				}
			}
			#:add news if no match found::::::::::::::::::::::::::::
			if {$ismatch != 1} {
				set cachetitles($feed,$cacheindex($feed)) $title
				set cachelinks($feed,$cacheindex($feed)) $link
				set cachedescs($feed,$cacheindex($feed)) $descr
				puts "Breaking News ~ $feed ~ $cacheindex($feed) ~ $cachetitles($feed,$cacheindex($feed))"
				incr cacheindex($feed)
			}
			set match 0
		}
	} else {
		puts "no data"
	}
}
proc trim_cache {feed} {
	variable dbindex; variable dbtitles; variable dblinks; variable dbdescs
	variable cachetitles; variable cachelinks; variable cachedescs; variable cacheindex
	variable maxcache
	if {![info exists dbindex($feed)]} {set dbindex($feed) 1}
	set count 0
	foreach item [array names cachetitles "$feed*"] {
		incr count
	}
	puts "$count items found."
	if {($count > $maxcache)} {
		puts "greater than $maxcache."
		set cindex 1
		while {$count > $maxcache} {
			puts "loop $count"
			if {![info exists cachetitles($feed,$cindex)]} {break}
			set dbtitles($feed,$dbindex($feed)) $cachetitles($feed,$cindex)
			set dblinks($feed,$dbindex($feed)) $cachelinks($feed,$cindex)
			set dbdescs($feed,$dbindex($feed)) $cachedescs($feed,$cindex)
			puts "Added to $feed database at $dbindex($feed): $dbtitles($feed,$dbindex($feed)) from cache $cindex"
			incr dbindex($feed)
			incr cindex
			incr count -1
		}
		puts "final cindex is $cindex increasing by 1 for cache reorder."
		
		#break
		#incr cindex
		set nindex 1
		while {($nindex <= $count)} {
			set cachetitles($feed,$nindex) $cachetitles($feed,$cindex)
			set cachelinks($feed,$nindex) $cachelinks($feed,$cindex)
			set cachedescs($feed,$nindex) $cachedescs($feed,$cindex)
			puts "moved $feed $cindex to $feed $nindex"
			incr nindex; incr cindex
		}
	} else {puts "nothing to do."}
}
proc cget {feed index} {
	#:output news item stored at <feed> <index>:::::::::::::::::::::::::::::
	variable cachetitles; variable cachelinks; variable cachedescs
	puts "Title ~ $cachetitles($feed,$index)"
	puts "Link ~ $cachelinks($feed,$index)"
	set desc [descdecode $cachedescs($feed,$index)]
	puts "Description ~ $desc"
}
proc dget {feed index} {
	#:output news item stored at <feed> <index>:::::::::::::::::::::::::::::
	variable dbtitles; variable dblinks; variable dbdescs
	puts "Title ~ $dbtitles($feed,$index)"
	puts "Link ~ $dblinks($feed,$index)"
	set desc [descdecode $dbdescs($feed,$index)]
	puts "Description ~ $desc"
}
proc unhtml {data} {
	#:remove html tags from data::::::::::::::::::::::::::::::::::::::::::::
	regsub -all "(?:<b>|</b>|<b />|<em>|</em>|<strong>|</strong>)" $data"\002" data
	regsub -all "(?:<u>|</u>|<u />)" $data "\037" data
	regsub -all "(?:<br>|<br/>|<br />)" $data ". " data
	regsub -all "<script.*?>.*?</script>" $data "" data
	regsub -all "<style.*?>.*?</style>" $data "" data
	regsub -all -- {<.*?>} $data " " data
	while {[string match "*  *" $data]} { regsub -all "  " $data " " data }
	return [string trim $data]
}

proc descdecode {data} {
	#:cleanup html markups.borrowed from webby::::::::::::::::::::::::::::::
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
	set data [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\\" "\\\\"] [string map $escapes $data]]
	regsub -all -- {&#([[:digit:]]{1,5});} $data {[format %c [string trimleft "\1" "0"]]} data
	regsub -all -- {&#x([[:xdigit:]]{1,4});} $data {[format %c [scan "\1" %x]]} data
	regsub -all -- {\\x([[:xdigit:]]{1,2})} $data {[format %c [scan "\1" %x]]} data
	set data [subst "$data"]
	return $data
}

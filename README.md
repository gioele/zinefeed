zinefeed: assemble an ebook from a news feed
============================================

**zinefeed** is a small Ruby program that assembles the articles published in
a news feed (RSS, Atom) into an ePub ebook.


Usage
-----

Launch **zinefeed** specifying the URI of the feed you want to read. It will
create an ePub with all the articles published in the last week.

    $ zinefeed https://lwn.net/headlines/newrss

It is possible to specify the number of days worth of articles to retrieve,
for example just 3.

    $ zinefeed --days 3 https://lwn.net/headlines/newrss


Authors
-------

* Gioele Barabucci <http://svario.it/gioele>


License
-------

This is free software released into the public domain (CC0 license).

See the `COPYING` file or <http://creativecommons.org/publicdomain/zero/1.0/>
for more details.

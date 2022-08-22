rsub ![Run tests](https://github.com/gaborbata/rsub/workflows/Run%20tests/badge.svg)
====

Ruby script which changes the timing of srt (SubRip) subtitle files.

Features:

* time shift
* change framerate (fps) from 23.976 to 25 and vice versa
* processing srt files in batch

SubRip text file format
-----------------------
SubRip (SubRip Text) files are named with the extension `.srt`, and contain formatted lines of plain text in groups separated by a blank line.
Subtitles are numbered sequentially, starting at 1. The timecode format used is `hours:minutes:seconds,milliseconds` with time units fixed to two zero-padded digits and fractions fixed to three zero-padded digits (00:00:00,000).
The fractional separator used is the comma. The subtitle separator, a blank line, is the double byte MS-DOS CR+LF pair, though the POSIX single byte linefeed is also well supported.

**Subtitle file structure:**

1. A numeric counter identifying each sequential subtitle
2. The time that the subtitle should appear on the screen, followed by `-->` and the time it should disappear
3. Subtitle text itself on one or more lines
4. A blank line containing no text, indicating the end of this subtitle

The same is repeated for the next subtitle.

**Example:**

    1
    00:02:17,440 --> 00:02:20,375
    Senator, we're making
    our final approach into Coruscant.

    2
    00:02:20,476 --> 00:02:22,501
    Very good, Lieutenant.

Usage
-----

    Usage: rsub.rb [options] file_path

    Specific options:
        -s, --shift N                    Shift subtitles by N seconds (float)
        -f, --fps FPS                    Change frame rate (23, 25)
                                         23: 25.000 fps -> 23,976 fps
                                         25: 23.976 fps -> 25.000 fps
        -b, --no-backup                  Do not create backup files
        -u, --use-backup-as-input        Use backup files as input
        -r, --no-recount                 Do not recount subtitle numbering
        -e, --encoding ENCODING          Subtitle encoding (default: ISO-8859-2)
        -h, --help                       Show this message

**Examples:**

Change frame rate from 25 fps to 23.976 fps and shift subtitles by 5 seconds forward:

    rsub.rb -f 23 -s 5 example.srt

Shift subtitles by 10 seconds and 5 milliseconds backward:

    rsub.rb -s -10.5 example.srt

Change frame rate from 23.976 fps to 25 fps for all subtitles recursively (please note single quotes):

    rsub.rb -f 25 '**/*.srt'

How to install
--------------

    gem install rsub

License
-------
Copyright (c) 2014-2017 Gabor Bata

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

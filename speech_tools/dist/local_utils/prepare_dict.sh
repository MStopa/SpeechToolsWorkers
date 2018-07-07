#!/bin/bash

# Copyright 2010-2012 Microsoft Corporation  
#           2012-2014 Johns Hopkins University (Author: Daniel Povey)
#                2015 Guoguo Chen

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.

# Call this script from one level above, e.g. from the s3/ directory.  It puts
# its output in data/local/.

# The parts of the output of this that will be needed are
# [in data/local/dict/ ]
# lexicon.txt
# extra_questions.txt
# nonsilence_phones.txt
# optional_silence.txt
# silence_phones.txt

set -e -o pipefail

g2p_server="localhost:5000"

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh

if [ $# -ne 2 ]; then
  echo "Usage: ./local/prepare_lang.sh <data_dir> <dict_dir>"
  echo "Creates a folder <dict_dir> with lexicon derived from"
  echo "  transcriptions in <data_dir>."
  exit 1
fi

data_dir=$1
dir=$2

mkdir -p $dir

# Make phones symbol-table (adding in silence and verbal and non-verbal noises at this point).
# We are adding suffixes _B, _E, _S for beginning, ending, and singleton phones.

# silence phones, one per line.
(echo sil; echo spn) > $dir/silence_phones.txt
echo sil > $dir/optional_silence.txt

# nonsilence phones; on each line is a list of phones that correspond
# really to the same base phone.
printf "I\nS\nZ\na\nb\nd\ndZ\ndz\ndzi\ne\nen\nf\ng\ni\nj\nk\nl\nm\nn\nni\no\non\np\nr\ns\nsi\nt\ntS\nts\ntsi\nu\nv\nw\nx\nz\nzi\n" > $dir/nonsilence_phones.txt

# A few extra questions that will be added to those obtained by automatically clustering
# the "real" phones.  These ask about stress; there's also one for silence.
cat $dir/silence_phones.txt| awk '{printf("%s ", $1);} END{printf "\n";}' > $dir/extra_questions.txt || exit 1;
cat $dir/nonsilence_phones.txt | perl -e 'while(<>){ foreach $p (split(" ", $_)) {
  $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$2} .= "$p "; } } foreach $l (values %q) {print "$l\n";}' \
 >> $dir/extra_questions.txt || exit 1;

#Get wordlist from data transcription
cat $data_dir/text | cut -f2- -d' ' | tr ' ' '\n' | sort -u | grep -iv "<unk>" > $dir/word.list

#Transcribe the wordlist

export LD_LIBRARY_PATH=$KALDI_ROOT/tools/openfst/lib
python2.7 $KALDI_ROOT/tools/phonetisaurus-g2p/src/scripts/phonetisaurus-apply  --model phonetisaurus/model.fst --lexicon phonetisaurus/lexicon.txt --word_list $dir/word.list -p 0.8 > $dir/lexicon_raw_nosil.txt

sort -u $dir/lexicon_raw_nosil.txt -o $dir/lexicon_raw_nosil.txt

# Add the silences, noises etc.
# the sort | uniq is to remove a duplicated pron.
# lexicon.txt is without the _B, _E, _S, _I markers.
(echo -e '!SIL\tsil'; echo -e '<SPOKEN_NOISE>\tspn'; echo -e '<unk>\tspn' ) | \
 cat - $dir/lexicon_raw_nosil.txt | sort -u > $dir/lexicon.txt || exit 1;

# Cleanup
rm -f $dir/lexiconp.txt
rm -f $dir/lexicon_raw_nosil.txt

echo "Dictionary preparation succeeded"


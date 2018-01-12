open FILE, $ARGV[0] or die "Can't open file!";
open OFILE, ">$ARGV[1]" or die "Can't open output!";

while ($line = <FILE>) {
  if ($line !~ /set device |set devicefamily |set package |set speedgrade/i) {
    print OFILE $line;
  }
}

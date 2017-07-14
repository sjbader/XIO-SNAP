#!/usr/bin/perl -w
#
# Script to create clones on XIO
#
# If you find this script useful, or are using it, please let me know!
#
# Stephen Bader
# sbader@gmail.com
#
# 7/14/16
# v 2.0
#

## Define several variables here
# XMS Server
my $xms = 'xms.abc.org';

# Cluster Name
my $clname = 'cluster1';

# Username for XMS
my $username = 'username';

# Password for XMS
my $password = 'password';

# Consistency Group Name
my $cgname = "CG-NAME";

# Who mail should go to - use an alias or separate multiple address with a semicolon
my $mailto = 'to@address.com';

# Who mail should come from
my $mailfrom = 'from@address.com';

# Subject of email
my $mailsubject = 'XIO Clone Creation';

# Log File
my $logfile = '/home/epicadm/bin/xio_epic_snap.log';

##
## In order for this to work, the consistency group needs to exist first
## Also must be on at least 4.0.2 code of XIO software
##

use strict;
use MIME::Base64;
use LWP;
use LWP::UserAgent;
use Getopt::Long;
use Mail::Sendmail;
use vars qw($opt_h);
my $sup = 0;
my $nosup = 0;
my $create = 0;
my $all = 0;
my $help = 0;
my $nomail = 0;
my $nofreeze = 0;
my $nomount = 0;
GetOptions ("sup-only" => \$sup, "create-snapshot-sets" => \$create,
	    "all" => \$all, "no-sup" => \$nosup, "help" => \$help,
	    "no-mail" => \$nomail, "no-freeze" => \$nofreeze,
	    "no-mount" => \$nomount);

## Check to see if we were asked to create the snapshot sets
if ($create == 1) {
	&logger("Creating snapshot sets");
	# Create SUP Snapshot set (for SUP)
	&create_snapshot_set('SUP', 'RW');
	# Create "RW" snapshot set (for future use, extra clone)
	&create_snapshot_set('RW', 'RW');
	# Create "RO" snaptshot set (for backups)
	&create_snapshot_set('RO', 'RO');
	# Create a snapshot set for each day of week (weekly clone copy)
	&create_snapshot_set('MON', 'RW');
	&create_snapshot_set('TUE', 'RW');
	&create_snapshot_set('WED', 'RW');
	&create_snapshot_set('THU', 'RW');
	&create_snapshot_set('FRI', 'RW');
	&create_snapshot_set('SAT', 'RW');
	&create_snapshot_set('SUN', 'RW');
	# Don't do anything else
	exit;
} # Done creating snapshot sets

## Either refreshing SUP or all clones is required
if ($sup == 0 && $all == 0) {
	&help();
}

## Display help page
if ($help == 1) {
	&help();
}

## Redirect STDOUT to a variable if we're sending email
my $output;
if ($nomail == 0) {
	close(STDOUT);
	open(STDOUT, '>', \$output) || die("Unable to redirect STDOUT: $!\n");
} # End STDOUT redirection

## If we were asked to refresh all clones
if ($all == 1) {
	## Log what we're doing ##
	&logger("Refreshing all clones");

	## Get day of week info for weekly clone copy
	my @wday = qw/MON TUE WED THU FRI SAT SUN/;
	my $day = $wday[ (localtime(time))[6] - 1 ];

	## Freeze Cache ##
	&freeze_cache();

	if ( $nosup == 1 ) {
	  &logger("Skipping SUP rename '--no-sup CLI'");
	} else {
	  ## Rename the SUP clone
	  &rename_clone('SUP');
	}

	## Rename the RO clone
	&rename_clone('RO');

	## Rename the RW clone
	&rename_clone('RW');

	## Rename the weekly clone copy
	&rename_clone($day);

	if ( $nosup == 1 ) {
	  &logger("Skipping SUP refresh '--no-sup CLI'");
	} else {
	  ## Refresh SUP clone
	  &refresh_clone('SUP');
	}

	## Refresh RO clone
	&refresh_clone('RO');

	## Refresh RW clone
	&refresh_clone('RW');

	## Refresh the weekly clone copy
	&refresh_clone($day);

	## Thaw Cache ##
	&thaw_cache();
	
	## Unmount/remount file system ##
	if ($nomount == 0) {
	   &unmount_mount();
	} else { 
	   &logger("Skipping unmount/mount '--no-mount CLI'");
	}
} # Done refreshing all clones

## If we're asked to only refresh SUP
if ($sup == 1) {
	## Log what we're doing ##
	&logger("Refreshing SUP only '--sup-only CLI'");

	## Freeze Cache ##
	&freeze_cache();

	## Rename the SUP clone
	&rename_clone('SUP');

	## Refresh SUP clone
	&refresh_clone('SUP');

	## Thaw Cache ##
	&thaw_cache();

	## Unmount/remount file system ##
	if ($nomount == 0) {
	   &unmount_mount();
	} else { 
	   &logger("Skipping unmount/mount '--no-mount CLI'");
	}
} # Done refreshing SUP only

## Send email about what was done
&send_email('0');

#######################################
### Function definitions below here ###
#######################################

## Logging function ##
sub logger() {
 print localtime() . " " . $_[0] . "\t\n";
} # End logger()

## Function to freeze Cache ##
sub freeze_cache() {
	if ( $nofreeze == 0 ) {
	    &logger("Freezing Cache");
	    if ( system("/usr/bin/ssh -l epicadm HOSTNAME /blah/blah/bin/instfreeze") == 0 ) {
		&logger("Cache Frozen!");
	    } else {
		&logger("Error Freezing Cache!");
		&send_email('1');
		exit;
	    }
	} else {
	    &logger("Skipping Cache Freeze 'CLI --no-freeze'");
	}
} # End freeze_cache()

## Function to thaw Cache ##
sub thaw_cache() {
	if ( $nofreeze == 0 ) {
	    &logger("Thawing Cache");
	    if ( system("/usr/bin/ssh -l epicadm HOSTNAME /blah/blah/bin/instthaw") == 0 ) {
		&logger("Cache Thawed!");
	    } else {
		&logger("Error Thawing Cache!");
		&send_email('1');
		exit;
	    }
	} else {
	    &logger("Skipping Cache Thaw 'CLI --no-freeze'");
	}
} # End thaw_cache()

## This function renames a clone. Requires Snapshot set suffix as input to function
## rename_clone('SUP') for example
sub rename_clone() {
 my $ssname = $cgname . "-" . $_[0];
 # Establish browser and URL
 my $browser = LWP::UserAgent->new;
 $browser->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
 my $url = 'https://' . $xms . "/api/json/v2/types/snapshot-sets?cluster-name=$clname&name=$ssname";

 # Custom fields
 my $req = HTTP::Request->new("PUT" => "$url");

 # Authentication Header Encoding
 my $encoded = $username . ":" . $password;
 $req->header('Authorization' => 'Basic ' . encode_base64($encoded));

 # Build post data
 my $sstmpname = $ssname . '-tmp';
 my $put_data = "{\"new-name\" : \"$sstmpname\"
	 	}";

 # Add content to request
 $req->content($put_data);

 # Post request
 my $response = $browser->request($req);

 if (! $response->is_success ) {
	&logger("Error renaming old $ssname. Aborting!");
	&thaw_cache();
	&logger("Error messages below:");
 	print $response->decoded_content;
 	print $response->status_line;
	&send_email('1');
	exit;
 } else {
	&logger("Renamed clone: $ssname");
 }
} # End rename_clone

## This function refreshes a clone. Requires snapshot set suffix as input to function
## refresh_clone('SUP') for example
sub refresh_clone() {
 my $ssname = $cgname . "-" . $_[0];
 # Establish browser and URL
 my $browser = LWP::UserAgent->new;
 $browser->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
 my $url = 'https://' . $xms . '/api/json/v2/types/snapshots?cluster-name=' . $clname;

 # Custom fields
 my $req = HTTP::Request->new(POST => "$url");

 # Build post data
 my $sstmpname = $ssname . '-tmp';
 my $post_data = "{\"from-consistency-group-id\" : \"$cgname\",
		  \"to-snapshot-set-id\" : \"$sstmpname\",
		  \"no-backup\" : \"true\",
		  \"snapshot-set-name\" : \"$ssname\"
	 	}";

 # Add content to request
 $req->content($post_data);

 # Add authentication header
 my $encoded = $username . ":" . $password;
 $req->header('Authorization' => 'Basic ' . encode_base64($encoded));

 # Post request
 my $response = $browser->request($req);

 if (! $response->is_success ) {
	&logger("Unable to refresh $ssname. Aborting!");
	&thaw_cache();
	&logger("Error messages below:");
 	print $response->decoded_content;
 	print $response->status_line;
	&send_email('1');
	exit;
 } else {
	&logger("Refreshed clone: $ssname");
 }
} # End refresh_clone()

## This function creates snapshot set. Requires snapshot set suffix as input to function
## And RO or RW
## create_snapshot_set('SUP', 'RO') for example
sub create_snapshot_set() {
 my $ssname = $cgname . "-" . $_[0];
 my $type = $_[1];
 # Establish browser and URL
 my $browser = LWP::UserAgent->new;
 $browser->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
 my $url = 'https://' . $xms . '/api/json/v2/types/snapshots?cluster-name=' . $clname;

 # Custom fields
 my $req = HTTP::Request->new(POST => "$url");

 # Build post data
 my $sstmpname = $ssname . '-tmp';
 my $post_data;
 if ( $type eq "RO" ) {
 	$post_data = "{\"consistency-group-id\" : \"$cgname\",
			  \"snapshot-set-name\" : \"$ssname\",
			  \"snapshot-type\" : \"readonly\"
		 	}";
 } else {
	$post_data = "{\"consistency-group-id\" : \"$cgname\",
			  \"snapshot-set-name\" : \"$ssname\"
		 	}";
 }

 # Add content to request
 $req->content($post_data);

 # Add authentication header
 my $encoded = $username . ":" . $password;
 $req->header('Authorization' => 'Basic ' . encode_base64($encoded));

 # Post request
 my $response = $browser->request($req);

 if (! $response->is_success ) {
	print "Unable to create snapshot set $ssname. Aborting!\n";
	print "Error messages below:\n\n";
 	print $response->decoded_content;
 	print $response->status_line;
	&send_email('1');
	exit;
 } else {
	print "Created snapshot set $ssname\n";
 }
} # End create_snapshot_set()

## Function to send email notifications
sub send_email() {
 my $error = $_[0];
 if ( $nomail != 1 ) {
   my $subject;
   if ($error == 1) {
	$subject = "!!!! Errors Encountered !!!! " . $mailsubject;
   } else {
	$subject = $mailsubject;
   }
   my %mail = ( To => $mailto,
	      From => $mailfrom,
	      Subject => $subject,
	      Message => $output
	    );
   open(LOG, '>>', $logfile) || die("Unable to open logfile: $!\n");
   print LOG $output;
   close(LOG);
   sendmail(%mail) || print("Unable to send mail: " . $Mail::Sendmail::error);
 }
} # End send email

## Function to unmount/mount file systems
sub unmount_mount() {
  &logger("Unmounting file systems");
  system("/bin/sudo /sbin/fuser -km /file/system01");
  system("/bin/sudo /bin/umount -l /file/system01");
  &logger("Mounting file system");
  system("/bin/sudo /bin/mount -a");
} # End unmount/mount

sub help() {
        print "
XIO Cloning Tool for Epic
Version 2.0

usage:

	--create-snapshot-sets	This will create the appropriate SnapShot sets on the XIO
	--sup-only		This will refresh the SUP SnapShot set ONLY
	--all			This will refresh ALL SnapShot sets
	--no-freeze		Do not Freeze and Thaw Cache
	--no-mail		By default, the script emails its output. This will display
				output on the CLI.
	--no-sup		Must be used in combination with --all, but skips the SUP
				SnapShot. Useful for restarting backups during the day.
	--no-mount		Do not unmount/remount file systems.
	--help			This help screen
	

Basic Info:
	You must configure the variables within the script first.

	The script will create the following SnapShot sets:
		CGName-SUP	== For SUP (Read/Write)
		CGName-RW	== Clone mounted for backups (Read/Write)
		CGName-RO	== Extra Clone (Read-Only)
		CGName-MON	== Clone refreshed every Monday
		CGName-TUE	== Clone refreshed every Tuesday
		CGName-WED	== Clone refreshed every Wednesday
		CGName-THU	== Clone refreshed every Thursday
		CGName-FRI	== Clone refreshed every Friday
		CGName-SAT	== Clone refreshed every Saturday
		CGName-SUN	== Clone refreshed every Sunday

";
        exit;
}


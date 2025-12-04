package BBS::Universal::FileTransfer;
BEGIN { our $VERSION = '0.006'; }

use strict;
use warnings;
use Fcntl qw(:DEFAULT :flock);
use IO::Select;
use POSIX qw(:sys_wait_h);

sub filetransfer_initialize {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start FileTransfer Initialize']);
    $self->{'debug'}->DEBUG(['End FileTransfer Initialize']);
    return ($self);
} ## end sub filetransfer_initialize

sub files_type {
	my $self = shift;
	my $file = shift;

	$self->{'debug'}->DEBUG(['Start File Type']);
	my @tmp = split(/\./,$file);
	my $ext = uc(pop(@tmp));
	my $sth = $self->{'dbh'}->prepare('SELECT type FROM file_types WHERE extension=?');
	$sth->execute($ext);
	my $name;
	if ($sth->rows > 0) {
		$name = $sth->fetchrow_array();
	}
	$sth->finish();
	$self->{'debug'}->DEBUG(['End File Type']);
	return($ext,$name);
}

sub files_load_file {
	my $self = shift;
	my $file = shift;

	$self->{'debug'}->DEBUG(['Start Files Load File']);
	my $filename = sprintf('%s.%s', $file, $self->{'USER'}->{'text_mode'});
	$self->{'CACHE'}->set(sprintf('SERVER %02d %s', $self->{'thread_number'},'CURRENT MENU FILE'), $filename);
	open(my $FILE, '<', $filename);
	my @text = <$FILE>;
	close($FILE);
	chomp(@text);
	$self->{'debug'}->DEBUG(['End Files Load File']);
	return (join("\n", @text));
}

sub files_list_summary {
	my $self   = shift;
	my $search = shift;

	$self->prompt('File Name? ');
	my $file = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});
	$self->{'debug'}->DEBUG(['Start Files List Summary']);
	my $sth;
	my $filter;
	if ($search) {
		$self->prompt('Search for');
		$filter = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});
		$sth    = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE (filename LIKE ? OR title LIKE ?) AND category_id=? ORDER BY uploaded DESC');
		$sth->execute('%' . $filter . '%', '%' . $filter . '%', $self->{'USER'}->{'file_category'});
	} else {
		$sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
		$sth->execute($self->{'USER'}->{'file_category'});
	}
	my @files;
	my $max_filename = 10;
	my $max_title    = 20;
	if ($sth->rows > 0) {
		while (my $row = $sth->fetchrow_hashref()) {
			push(@files, $row);
			$max_filename = max(length($row->{'filename'}), $max_filename);
			$max_title    = max(length($row->{'title'}),    $max_title);
		}
		my $table = Text::SimpleTable->new($max_filename, $max_title);
		$table->row('FILENAME', 'TITLE');
		$table->hr();
		foreach my $record (@files) {
			$table->row($record->{'filename'}, $record->{'title'});
		}
		my $mode = $self->{'USER'}->{'text_mode'};
		if ($mode eq 'ANSI') {
			my $text = $table->boxes2('MAGENTA')->draw();
			while ($text =~ / (FILENAME|TITLE) /s) {
				my $ch = $1;
				my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
				$text =~ s/ $ch / $new /gs;
			}
			$self->output("\n$text");
		} elsif ($mode eq 'ATASCII') {
			$self->output("\n" . $self->color_border($table->boxes->draw(),'MAGENTA'));
		} elsif ($mode eq 'PETSCII') {
			my $text = $table->boxes->draw();
			while ($text =~ / (FILENAME|TITLE) /s) {
				my $ch = $1;
				my $new = '[% YELLOW %]' . $ch . '[% RESET %]';
				$text =~ s/ $ch / $new /gs;
			}
			$self->output("\n" . $self->color_border($text,'PURPLE'));
		} else {
			$self->output("\n" . $table->draw());
		}
	} elsif ($search) {
		$self->output("\nSorry '$filter' not found");
	} else {
		$self->output("\nSorry, this file category is empty\n");
	}
	$self->output("\nPress a key to continue ...");
	$self->get_key(ECHO, BLOCKING);
	$self->{'debug'}->DEBUG(['End Files List Summary']);
	return (TRUE);
}

sub files_choices {
	my $self   = shift;
	my $record = shift;
	my $view   = FALSE;
	my $mapping = {
		'TEXT' => '',
		'Z'    => {
			'command'      => 'BACK',
			'color'        => 'WHITE',
			'access_level' => 'USER',
			'text'         => 'Return to File Menu',
		},
		'N' => {
			'command'      => 'NEXT',
			'color'        => 'BLUE',
			'access_level' => 'USER',
			'text'         => 'Next file',
		},
		'D' => {
			'command'      => 'DOWNLOAD',
			'color'        => 'CYAN',
			'access_level' => 'VETERAN',
			'text'         => 'Download file',
		},
		'R' => {
			'command'      => 'REMOVE FILE',
			'color'        => 'RED',
			'access_level' => 'JUNIOR SYSOP',
			'text'         => 'Remove file',
		},
	};
	if ($record->{'extension'} =~ /^(TXT|ASC|ATA|PET|VT|ANS|MD|INF|CDF|PL|PM|PY|C|CPP|H|SH|CSS|HTM|HTML|SHTML|JS|JAVA|XML|BAT)$/ && $self->check_access_level('VETERAN')) {
		$view = TRUE;
		$mapping->{'V'} = {
			'command'      => 'VIEW FILE',
			'color'        => 'CYAN',
			'access_level' => 'VETERAN',
			'text'         => 'View file',
		};
	};
	$self->show_choices($mapping);
	$self->prompt('Choose');
	my $key;
	do {
		$key = uc($self->get_key());
	} until($key =~ /D|N|Z/ || ($key eq 'V' && $view) || ($key eq 'R' && $self->check_access_level('JUNION SYSOP')));
	$self->output($mapping->{$key}->{'command'} . "\n");
	if ($mapping->{$key}->{'command'} eq 'DOWNLOAD') {
		my $file = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $record->{'filename'};
		$mapping = {
			'B'    => {
				'command'      => 'BACK',
				'color'        => 'WHITE',
				'access_level' => 'USER',
				'text'         => 'Return to File Menu',
			},
			'Y' => {
				'command'      => 'YMODEM',
				'color'        => 'YELLOW',
				'access_level' => 'VETERAN',
				'text'         => 'Download with the Ymodem protocol',
			},
			'X' => {
				'command'      => 'XMODEM',
				'color'        => 'BRIGHT BLUE',
				'access_level' => 'VETERAN',
				'text'         => 'Download with the Xmodem protocol',
			},
			'Z' => {
				'command'      => 'ZMODEM',
				'color'        => 'GREEN',
				'access_level' => 'VETERAN',
				'text'         => 'Download with the Zmodem protocol',
			},
		};
		$self->show_choices($mapping);
		$self->prompt('Choose');
		do {
			$key = uc($self->get_key());
		} until($key =~ /B|X|Y|Z/);
		$self->output($mapping->{$key}->{'command'});
		if ($mapping->{$key}->{'command'} eq 'XMODEM') {
			system('sz', '--xmodem', '--quiet', '--binary', $file);
		} elsif ($mapping->{$key}->{'command'} eq 'YMODEM') {
			system('sz', '--ymodem', '--quiet', '--binary', $file);
		} elsif ($mapping->{$key}->{'command'} eq 'ZMODEM') {
			system('sz', '--zmodem', '--quiet', '--binary', '--resume', $file);
		} else {
			return(FALSE);
		}
		return(TRUE);
	} elsif ($mapping->{$key}->{'command'} eq 'VIEW FILE' && $self->check_access_level($mapping->{$key}->{'access_level'})) {
		my $file = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $record->{'filename'};
		open(my $VIEW,'<',$file);
		binmode($VIEW, ":encoding(UTF-8)");
		my $data;
		read($VIEW, $data, $record->{'file_size'}, 0);
		close($VIEW);
		$self->output('[% CLS %]' . $data . '[% RESET %]');
		return(TRUE);
	} elsif ($mapping->{$key}->{'command'} eq 'REMOVE FILE' && $self->check_access_level($mapping->{$key}->{'access_level'})) {
		return(TRUE);
	} elsif ($mapping->{$key}->{'command'} eq 'NEXT') {
		return(TRUE);
	}
	return(FALSE);
}

sub files_upload_choices {
	my $self   = shift;
	my $ckey;

	$self->prompt('File Name? ');
	my $file = $self->get_line({ 'type' => FILENAME, 'max' => 255, 'default' => ''});
	my $ext  = uc($file =~ /\.(.*?)$/);

	$self->prompt('Title (Fiendly name)? ');
	my $title = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});

	$self->prompt('Description? ');
	my $description = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});

	my $file_category = $self->{'USER'}->{'file_category'};

	my $mapping = {
		'B'    => {
			'command'      => 'BACK',
			'color'        => 'WHITE',
			'access_level' => 'USER',
			'text'         => 'Return to File Menu',
		},
		'Y' => {
			'command'      => 'YMODEM',
			'color'        => 'YELLOW',
			'access_level' => 'VETERAN',
			'text'         => 'Upload with the Ymodem protocol',
		},
		'X' => {
			'command'      => 'XMODEM',
			'color'        => 'BRIGHT BLUE',
			'access_level' => 'VETERAN',
			'text'         => 'Upload with the Xmodem protocol',
		},
		'Z' => {
			'command'      => 'ZMODEM',
			'color'        => 'GREEN',
			'access_level' => 'VETERAN',
			'text'         => 'Upload with the Zmodem protocol',
		},
	};
	$self->show_choices($mapping);
	$self->prompt('Choose');
	do {
		$ckey = uc($self->get_key());
	} until($ckey =~ /B|X|Y|Z/);
	$self->output($mapping->{$ckey}->{'command'});
	if ($mapping->{$ckey}->{'command'} eq 'XMODEM') {
		if ($self->files_receive_file($file,XMODEM)) {
			my $filename = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $file;
			my $size     = (-s $filename);
			my $sth      = $self->{'dbh'}->prepare('INSERT INTO files (category,filename,title,file_type,description,file_size) VALUES (?,?,?,(SELECT id FROM file_types WHERE extension=?),?,?');
			$sth->execute($file_category,$file,$title,$ext,$description,$size);
			$sth->finish();
		}
	} elsif ($mapping->{$ckey}->{'command'} eq 'YMODEM') {
		if ($self->files_receive_file($file,YMODEM)) {
			my $filename = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $file;
			my $size     = (-s $filename);
			my $sth      = $self->{'dbh'}->prepare('INSERT INTO files (category,filename,title,file_type,description,file_size) VALUES (?,?,?,(SELECT id FROM file_types WHERE extension=?),?,?');
			$sth->execute($file_category,$file,$title,$ext,$description,$size);
			$sth->finish();
		}
	} elsif ($mapping->{$ckey}->{'command'} eq 'ZMODEM') {
		if ($self->files_receive_file($file,ZMODEM)) {
			my $filename = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $file;
			my $size     = (-s $filename);
			my $sth      = $self->{'dbh'}->prepare('INSERT INTO files (category,filename,title,file_type,description,file_size) VALUES (?,?,?,(SELECT id FROM file_types WHERE extension=?),?,?');
			$sth->execute($file_category,$file,$title,$ext,$description,$size);
			$sth->finish();
		}
	} else {
		return(FALSE);
	}
	if ($? == -1) {
		$self->{'debug'}->ERROR(["Could not execute rz:  $!"]);
	} elsif ($? & 127) {
		$self->{'debug'}->ERROR(["File Transfer Aborted:  $!"]);
	} else {
		$self->{'debug'}->DEBUG(['File Transfer Successful']);
	}
	return(TRUE);
}

sub files_list_detailed {
	my $self   = shift;
	my $search = shift;

	$self->{'debug'}->DEBUG(['Start Files List Detailed']);
	my $sth;
	my $filter;
	my $columns = $self->{'USER'}->{'max_columns'};
	if ($search) {
		$self->prompt('Search for');
		$filter = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});
		$sth    = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE (filename LIKE ? OR title LIKE ?) AND category_id=? ORDER BY uploaded DESC');
		$sth->execute('%' . $filter . '%', '%' . $filter . '%', $self->{'USER'}->{'file_category'});
	} else {
		$sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
		$sth->execute($self->{'USER'}->{'file_category'});
	}
	my @files;
	if ($sth->rows > 0) {
		$self->{'debug'}->DEBUGMAX(\@files);
		my $table;
		my $mode = $self->{'USER'}->{'text_mode'};
		while (my $row = $sth->fetchrow_hashref()) {
			push(@files, $row);
		}
		$sth->finish();
		foreach my $record (@files) {
			if ($mode eq 'ANSI') {
				$self->output("\n" . '[% HORIZONTAL RULE GREEN %]' . "\n");
				$self->output('[% B_BLUE %][% BRIGHT WHITE %]       TITLE [% RESET %] ' . $record->{'title'} . "\n");
				$self->output('[% B_BLUE %][% BRIGHT WHITE %]    FILENAME [% RESET %] ' . $record->{'filename'} . "\n");
				$self->output('[% B_BLUE %][% BRIGHT WHITE %]   FILE SIZE [% RESET %] ' . format_number($record->{'file_size'}) . "\n");
				if ($record->{'prefer_nickname'}) {
					$self->output('[% B_BLUE %][% BRIGHT WHITE %]    UPLOADER [% RESET %] ' . $record->{'nickname'} . "\n");
				} else {
					$self->output('[% B_BLUE %][% BRIGHT WHITE %]    UPLOADER [% RESET %] ' . $record->{'fullname'} . "\n");
				}
				$self->output('[% B_BLUE %][% BRIGHT WHITE %]   FILE TYPE [% RESET %] ' . $record->{'type'} . "\n");
				$self->output('[% B_BLUE %][% BRIGHT WHITE %]    UPLOADED [% RESET %] ' . $record->{'uploaded'} . "\n");
				$self->output('[% B_BLUE %][% BRIGHT WHITE %]      THUMBS [% RESET %] [% THUMBS UP SIGN %] ' . (0 + $record->{'thumbs_up'}) . '   [% THUMBS DOWN SIGN %] ' . (0 + $record->{'tumbs_down'}) . "\n");
				$self->output('[% HORIZONTAL RULE GREEN %]' . "\n");
			} else {
				$self->output("\n      TITLE: " . $record->{'title'} . "\n");
				$self->output('   FILENAME: ' . $record->{'filename'} . "\n");
				$self->output('  FILE SIZE: ' . format_number($record->{'file_size'}) . "\n");
				if ($record->{'prefer_nickname'}) {
					$self->output('   UPLOADER: ' . $record->{'nickname'} . "\n");
				} else {
					$self->output('   UPLOADER: ' . $record->{'fullname'} . "\n");
				}
				$self->output('  FILE TYPE: ' . $record->{'type'} . "\n");
				$self->output('   UPLOADED: ' . $record->{'uploaded'} . "\n");
				$self->output('  THUMBS UP: ' . (0 + $record->{'thumbs_up'}) . "\n");
				$self->output('THUMBS DOWN: ' . (0 + $record->{'thumbs_down'}) . "\n");
			}
			last unless($self->files_choices($record));
		}
	} elsif ($search) {
		$self->output("\nSorry '$filter' not found");
	} else {
		$self->output("\nSorry, this file category is empty\n");
	}
	$self->output("\nPress a key to continue ...");
	$self->get_key(ECHO, BLOCKING);
	$self->{'debug'}->DEBUG(['End Files List Detailed']);
	return (TRUE);
}

sub files_save_file {
	my $self = shift;
	$self->{'debug'}->DEBUG(['Start Save File']);
	$self->{'debug'}->DEBUG(['End Save File']);
	return (TRUE);
}

sub files_receive_file {
	my $self     = shift;
	my $file     = shift;
	my $protocol = shift;

	my $success = TRUE;
	$self->{'debug'}->DEBUG(['Start Receive File']);
	unless ($self->{'local_mode'}) {
#		chdir $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'};
#		select $self->{'cl_socket'};
		if ($protocol == YMODEM) {
			$self->{'debug'}->DEBUG(["Send file $file with Ymodem"]);
			$success = $self->files_receive_file_ymodem($self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . '/' . $file);
#			system('rz', '--binary', '--quiet', '--ymodem', '--rename', '--restricted', '--restricted');
		} elsif ($protocol == ZMODEM) {
			$self->{'debug'}->DEBUG(["Send file $file with Zmodem"]);
			$success = $self->files_receive_file_zmodem($self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . '/' . $file);
#			system('rz', '--binary', '--quiet', '--zmodem', '--rename', '--restricted', '--restricted');
		} else { # Xmodem
			$success = $self->files_receive_file_xmodem($self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . '/' . $file);
			$self->{'debug'}->DEBUG(["Send file $file with Xmodem"]);
#			system('rx', '--binary', '--quiet', '--xmodem', $file);
		}
#		select STDOUT;
	} else {
		$self->output("Upload not allowed in local mode\n");
	}
#	chdir $self->{'CONF'}->{'BBS ROOT'};
	$self->{'debug'}->DEBUG(['End Receive File']);
	return($success);
}

sub files_receive_file_xmodem {
	my ($self, $file) = @_;
}

sub files_receive_file_ymodem {
	my ($self, $file) = @_;
}

sub files_receive_file_zmodem {
	my ($self, $file) = @_;
}

# CRC16-CCITT (XMODEM) calculation
sub _crc16_bytes {
    my ($data) = @_;
    my $crc = 0x0000;
    foreach my $ch (split //, $data) {
        $crc ^= (ord($ch) << 8);
        for (1 .. 8) {
            if ($crc & 0x8000) {
                $crc = (($crc << 1) & 0xFFFF) ^ 0x1021;
            } else {
                $crc = ($crc << 1) & 0xFFFF;
            }
        } ## end for (1 .. 8)
    } ## end foreach my $ch (split //, $data)
    return chr(($crc >> 8) & 0xFF) . chr($crc & 0xFF);
} ## end sub _crc16_bytes

# Read a single byte from socket with timeout (seconds)
sub _read_byte_timeout {
    my ($sock, $timeout) = @_;
    $timeout ||= 10;
    my $rin = '';
    my $rout;
    my $fileno = fileno($sock);
    return undef unless defined $fileno && $fileno >= 0;
    vec($rin, $fileno, 1) = 1;
    my $nfound = select($rout = $rin, undef, undef, $timeout);

    if ($nfound > 0) {
        my $buf = '';
        my $r   = sysread($sock, $buf, 1);
        return undef unless defined $r && $r == 1;
        return $buf;
    } ## end if ($nfound > 0)
    return undef;
} ## end sub _read_byte_timeout

# Send a single XMODEM/YMODEM block (128 or 1024) using CRC16
sub _send_block {
    my ($sock, $blknum, $data, $block_size) = @_;
    $block_size ||= 128;
    my $hdr = ($block_size == 1024) ? STX : SOH;
    $data .= chr(0x1A) x ($block_size - length($data));    # pad with SUB
    my $blk = $hdr . chr($blknum & 0xFF) . chr((~$blknum) & 0xFF) . $data;
    $blk .= _crc16_bytes($data);
    my $written = 0;
    my $len     = length($blk);

    while ($written < $len && $self->is_connected()) {
        my $rv = syswrite($sock, substr($blk, $written), $len - $written);
        unless (defined $rv) {
            return 0;
        }
        $written += $rv;
    } ## end while ($written < $len)
    return 1;
} ## end sub _send_block

# XMODEM send (CRC mode preferred)
# Returns true on success, false on failure
sub files_send_xmodem {
    my ($self, $file) = @_;
    $self->{'debug'}->DEBUG(['Start files_send_xmodem']);
    my $sock = $self->{'cl_socket'};
    unless ($sock) {
        $self->{'debug'}->ERROR(["No client socket for XMODEM send"]);
        return 0;
    }
    my $path = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $file;
    unless (open my $fh, '<:raw', $path) {
        $self->{'debug'}->ERROR(["Cannot open file $path: $!"]);
        return 0;
    }

    # Wait for receiver request: 'C' (CRC) or NAK (checksum)
    my $init_char = _read_byte_timeout($sock, 60);
    unless (defined $init_char) {
        $self->{'debug'}->ERROR(["Timeout waiting for receiver to start XMODEM"]);
        close $fh;
        return 0;
    }

    my $use_crc = ($init_char eq C_CHAR);

    # we will always use CRC16 blocks

    my $blockno        = 1;
    my $success        = 1;
    my $retries_global = 0;
    my $eof            = 0;
    my $max_retries    = 10;

    while ($self->is_connected()) {
        my $data;
        my $n = read($fh, $data, 128);
        if (defined $n && $n > 0) {

            # send block
            my $send_ok  = 0;
            my $attempts = 0;
            while ($attempts < $max_retries && $self->is_connected()) {
                $attempts++;
                unless (_send_block($sock, $blockno, $data, 128)) {
                    $self->{'debug'}->ERROR(["Failed write while sending XMODEM block $blockno"]);
                    $success = 0;
                    last;
                }
                my $resp = _read_byte_timeout($sock, 10);
                unless (defined $resp) {
                    $self->{'debug'}->DEBUG(["No response for block $blockno, retry $attempts"]);
                    next;
                }
                if ($resp eq ACK) {
                    $send_ok = 1;
                    last;
                } elsif ($resp eq NAK) {
                    next;    # retransmit
                } elsif ($resp eq CAN) {
                    $self->{'debug'}->ERROR(["Received CAN during XMODEM send"]);
                    $success = 0;
                    last;
                } else {
                    # unexpected byte, retry
                    next;
                }
            } ## end while ($attempts < $max_retries)
            unless ($send_ok) { $success = 0; last; }
            $blockno = ($blockno + 1) % 256;
        } else {
            # EOF reached
            $eof = 1;
            last;
        } ## end else [ if (defined $n && $n >...)]
    } ## end while (1)

    if ($success) {
        # send EOT and wait for ACK
        my $sent = 0;
        for (1 .. 10) {
            syswrite($sock, EOT);
            my $r = _read_byte_timeout($sock, 10);
            if (defined $r && $r eq ACK) { $sent = 1; last; }
        }
        unless ($sent) {
            $self->{'debug'}->ERROR(["No ACK for EOT in XMODEM send"]);
            $success = 0;
        } else {
            $self->{'debug'}->DEBUG(['XMODEM send completed']);
        }
    } ## end if ($success)

    close $fh;
    $self->{'debug'}->DEBUG(['End files_send_xmodem']);
    return $success;
} ## end sub files_send_xmodem

# YMODEM send (simple implementation):
# - Send initial 128-byte header block with filename\0size\0
# - Then send data in 1024-byte STX blocks with CRC16
# Returns true on success, false otherwise
sub files_send_ymodem {
    my ($self, $file) = @_;
    $self->{'debug'}->DEBUG(['Start files_send_ymodem']);
    my $sock = $self->{'cl_socket'};
    unless ($sock) {
        $self->{'debug'}->ERROR(["No client socket for YMODEM send"]);
        return 0;
    }

    my $path = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $file;
    unless (open my $fh, '<:raw', $path) {
        $self->{'debug'}->ERROR(["Cannot open file $path: $!"]);
        return 0;
    }
    my $size = -s $path;
    $size = 0 unless defined $size;

    # Wait for initial 'C' (CRC) from receiver
    my $init_char = _read_byte_timeout($sock, 60);
    unless (defined $init_char) {
        $self->{'debug'}->ERROR(["Timeout waiting for receiver to start YMODEM"]);
        close $fh;
        return 0;
    }

    # prepare header block (block 0)
    my $header = $file . "\0" . $size . " ";
    $header .= "\0" x (128 - length($header));

    # send header block and expect ACK then 'C'
    unless (_send_block($sock, 0, $header, 128)) {
        $self->{'debug'}->ERROR(["Failed to send YMODEM header block"]);
        close $fh;
        return 0;
    }
    my $r1 = _read_byte_timeout($sock, 10);
    my $r2 = _read_byte_timeout($sock, 10);

    # r1 should be ACK and r2 should be 'C' to begin 1k transfer (some receivers differ)
    unless (defined $r1 && $r1 eq ACK) {
        $self->{'debug'}->ERROR(["No ACK after YMODEM header"]);
        close $fh;
        return 0;
    }

    # Send data blocks in 1K (1024) with STX header
    my $blockno = 1;
    my $success = 1;
    while ($self->is_connected()) {
        my $data;
        my $n = read($fh, $data, 1024);
        if (defined $n && $n > 0) {

            # send 1k block
            my $attempts = 0;
            my $sent_ok  = 0;
            while ($attempts < 10 && $self->is_connected()) {
                $attempts++;
                unless (_send_block($sock, $blockno, $data, 1024)) {
                    $self->{'debug'}->ERROR(["Failed write while sending YMODEM block $blockno"]);
                    $success = 0;
                    last;
                }
                my $resp = _read_byte_timeout($sock, 10);
                if (defined $resp && $resp eq ACK) { $sent_ok = 1; last; }
                if (defined $resp && $resp eq NAK) { next; }
                if (defined $resp && $resp eq CAN) { $self->{'debug'}->ERROR(["Received CAN during YMODEM send"]); $success = 0; last; }

                # else retry
            } ## end while ($attempts < 10)
            last unless $sent_ok && $success;
            $blockno = ($blockno + 1) % 256;
        } else {
            last;    # EOF
        }
    } ## end while (1)

    if ($success) {
        # End-of-file sequence: send EOT and expect ACK, then send an empty header block (block 0 with filename "")
        my $sent = 0;
        for (1 .. 10) {
            syswrite($sock, EOT);
            my $r = _read_byte_timeout($sock, 10);
            if (defined $r && $r eq NAK) {

                # some receivers expect NAK then ACK, repeat
                next;
            } elsif (defined $r && $r eq ACK) {
                $sent = 1;
                last;
            }
        } ## end for (1 .. 10)
        unless ($sent) {
            $self->{'debug'}->ERROR(["No ACK for EOT in YMODEM send"]);
            $success = 0;
        } else {
            # Send final empty header (indicates end of batch)
            my $empty_header = "\0" x 128;
            unless (_send_block($sock, 0, $empty_header, 128)) {
                $self->{'debug'}->ERROR(["Failed to send final empty YMODEM header"]);
                $success = 0;
            } else {
                my $r = _read_byte_timeout($sock, 10);    # expect ACK
                unless (defined $r && $r eq ACK) {
                    $self->{'debug'}->ERROR(["No ACK after final YMODEM header"]);
                    $success = 0;
                }
            } ## end else
        } ## end else
    } ## end if ($success)

    close $fh;
    $self->{'debug'}->DEBUG(['End files_send_ymodem']);
    return $success;
} ## end sub files_send_ymodem

# ZMODEM: too complex to implement reliably here in a short patch.
# Provide a placeholder that returns error and recommends alternatives.
sub files_send_zmodem {
    my ($self, $file) = @_;
    $self->{'debug'}->DEBUG(['Start files_send_zmodem (stub)']);

    # Optionally attempt to use a CPAN ZMODEM implementation if available:
    eval {
        require Protocol::Zmodem if 0;    # placeholder - no standard widely-used CPAN module guaranteed
    };
    $self->{'debug'}->ERROR(["ZMODEM send not implemented in pure-Perl in this module. Consider using lrzsz (sz) or a dedicated ZMODEM library/implementation."]);
    $self->{'debug'}->DEBUG(['End files_send_zmodem (stub)']);
    return 0;
} ## end sub files_send_zmodem

# files_send_file: route to appropriate pure-perl sender (X/Y) or Z stub
sub files_send_file {
    my $self     = shift;
    my $file     = shift;
    my $protocol = shift;

    my $success = TRUE;
    $self->{'debug'}->DEBUG(['Start Send File']);
    unless ($self->{'local_mode'}) {    # No file transfer in local mode
        if ($protocol == YMODEM) {
            $self->{'debug'}->DEBUG(["Send file $file with Ymodem (Perl)"]);
            $success = $self->files_send_ymodem($file);
        } elsif ($protocol == ZMODEM) {
            $self->{'debug'}->DEBUG(["Send file $file with Zmodem (stub)"]);
            $success = $self->files_send_zmodem($file);
        } else {    # Xmodem assumed
            $self->{'debug'}->DEBUG(["Send file $file with Xmodem (Perl)"]);
            $success = $self->files_send_xmodem($file);
        }
        chdir $self->{'CONF'}->{'BBS ROOT'};
    } else {
        $self->output("Download not allowed in local mode\n");
        $success = 0;
    }
    $self->{'debug'}->DEBUG(['End Send File']);
    return ($success);
} ## end sub files_send_file

1;

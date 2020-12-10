#! /usr/bin/perl -w
#
# patch_nspawn.pl: patches systemd-nspawn on Debian 9 for Docker
# by pts@fazekas.hu at Wed Dec  9 16:36:44 CET 2020
#

BEGIN { $^W = 1 } use integer; use strict;

die "Usage: $0 <source-systemd-nspawn> <destination-systemd-nspawn>\n" if @ARGV != 2;

# Linux capabilities.
sub CAP_SYS_ADMIN()  {21}
sub CAP_SYS_BOOT()   {22}
sub CAP_SYSLOG()     {34}
sub CAP_SYS_MODULE() {16}
sub CAP_SYS_PACCT()  {20}
sub CAP_SYS_PTRACE() {19}
sub CAP_SYS_RAWIO()  {17}
sub CAP_SYS_TIME()   {25}

# Linux seccomp syscall numbers.
my %SCMP_SYS = qw(
    _sysctl 156 add_key 248 afs_syscall 183 bdflush -10002 bpf 321 break
    -10003 create_module 174 ftime -10013 get_kernel_syms 177 getpmsg 181
    gtty -10022 kexec_file_load 320 kexec_load 246 keyctl 250 lock -10027
    lookup_dcookie 212 mpx -10030 nfsservctl 180 open_by_handle_at 304
    perf_event_open 298 prof -10039 profil -10040 putpmsg 182 query_module
    178 quotactl 179 request_key 249 security 185 sgetmask -10053 ssetmask
    -10061 stty -10065 swapoff 168 swapon 167 sysfs 139 tuxcall 184 ulimit
    -10069 uselib 134 ustat 136 vserver 236 syslog 103 delete_module 176
    finit_module 313 init_module 175 acct 163 process_vm_readv 310
    process_vm_writev 311 ptrace 101 ioperm 173 iopl 172 pciconfig_iobase
    -10086 pciconfig_read -10087 pciconfig_write -10088 s390_pci_mmio_read
    -10197 s390_pci_mmio_write -10198 adjtimex 159 clock_adjtime 305
    clock_settime 227 settimeofday 164 stime -10064
);

my @blacklists = ([
    # From systemd-232/src/nspawn/nspawn-seccomp.c
    # in systemd_232.orig.tar.gz with patches from systemd_232-25+deb9u12.debian.tar.xz
    # for Debian 9 on Linux (amd64, should be architecture-independent).
    [0,              $SCMP_SYS{_sysctl}],              # obsolete syscall
    [0,              $SCMP_SYS{add_key}],              # keyring is not namespaced
    [0,              $SCMP_SYS{afs_syscall}],          # obsolete syscall
    [0,              $SCMP_SYS{bdflush}],
    [0,              $SCMP_SYS{bpf}],
    [0,              $SCMP_SYS{break}],                # obsolete syscall
    [0,              $SCMP_SYS{create_module}],        # obsolete syscall
    [0,              $SCMP_SYS{ftime}],                # obsolete syscall
    [0,              $SCMP_SYS{get_kernel_syms}],      # obsolete syscall
    [0,              $SCMP_SYS{getpmsg}],              # obsolete syscall
    [0,              $SCMP_SYS{gtty}],                 # obsolete syscall
    [0,              $SCMP_SYS{kexec_file_load}],
    [0,              $SCMP_SYS{kexec_load}],
    [0,              $SCMP_SYS{keyctl}],               # keyring is not namespaced
    [0,              $SCMP_SYS{lock}],                 # obsolete syscall
    [0,              $SCMP_SYS{lookup_dcookie}],
    [0,              $SCMP_SYS{mpx}],                  # obsolete syscall
    [0,              $SCMP_SYS{nfsservctl}],           # obsolete syscall
    [0,              $SCMP_SYS{open_by_handle_at}],
    [0,              $SCMP_SYS{perf_event_open}],
    [0,              $SCMP_SYS{prof}],                 # obsolete syscall
    [0,              $SCMP_SYS{profil}],               # obsolete syscall
    [0,              $SCMP_SYS{putpmsg}],              # obsolete syscall
    [0,              $SCMP_SYS{query_module}],         # obsolete syscall
    [0,              $SCMP_SYS{quotactl}],
    [0,              $SCMP_SYS{request_key}],          # keyring is not namespaced
    [0,              $SCMP_SYS{security}],             # obsolete syscall
    [0,              $SCMP_SYS{sgetmask}],             # obsolete syscall
    [0,              $SCMP_SYS{ssetmask}],             # obsolete syscall
    [0,              $SCMP_SYS{stty}],                 # obsolete syscall
    [0,              $SCMP_SYS{swapoff}],
    [0,              $SCMP_SYS{swapon}],
    [0,              $SCMP_SYS{sysfs}],                # obsolete syscall
    [0,              $SCMP_SYS{tuxcall}],              # obsolete syscall
    [0,              $SCMP_SYS{ulimit}],               # obsolete syscall
    [0,              $SCMP_SYS{uselib}],               # obsolete syscall
    [0,              $SCMP_SYS{ustat}],                # obsolete syscall
    [0,              $SCMP_SYS{vserver}],              # obsolete syscall
    [CAP_SYSLOG,     $SCMP_SYS{syslog}],
    [CAP_SYS_MODULE, $SCMP_SYS{delete_module}],
    [CAP_SYS_MODULE, $SCMP_SYS{finit_module}],
    [CAP_SYS_MODULE, $SCMP_SYS{init_module}],
    [CAP_SYS_PACCT,  $SCMP_SYS{acct}],
    [CAP_SYS_PTRACE, $SCMP_SYS{process_vm_readv}],
    [CAP_SYS_PTRACE, $SCMP_SYS{process_vm_writev}],
    [CAP_SYS_PTRACE, $SCMP_SYS{ptrace}],
    [CAP_SYS_RAWIO,  $SCMP_SYS{ioperm}],
    [CAP_SYS_RAWIO,  $SCMP_SYS{iopl}],
    [CAP_SYS_RAWIO,  $SCMP_SYS{pciconfig_iobase}],
    [CAP_SYS_RAWIO,  $SCMP_SYS{pciconfig_read}],
    [CAP_SYS_RAWIO,  $SCMP_SYS{pciconfig_write}],
    [CAP_SYS_RAWIO,  $SCMP_SYS{s390_pci_mmio_read}],
    [CAP_SYS_RAWIO,  $SCMP_SYS{s390_pci_mmio_write}],
    [CAP_SYS_TIME,   $SCMP_SYS{adjtimex}],
    [CAP_SYS_TIME,   $SCMP_SYS{clock_adjtime}],
    [CAP_SYS_TIME,   $SCMP_SYS{clock_settime}],
    [CAP_SYS_TIME,   $SCMP_SYS{settimeofday}],
    [CAP_SYS_TIME,   $SCMP_SYS{stime}],
], [
    # From systemd-229/src/nspawn/nspawn.c
    # in systemd_229.orig.tar.gz with patches from systemd_229-4ubuntu21.29.debian.tar.xz
    # for Ubuntu 16.04 on Linux (amd64, should be architecture-independent).
    #
    # FYI No syscalls to enable here.
    [CAP_SYS_RAWIO,  $SCMP_SYS{iopl}],
    [CAP_SYS_RAWIO,  $SCMP_SYS{ioperm}],
    [CAP_SYS_BOOT,   $SCMP_SYS{kexec_load}],
    [CAP_SYS_ADMIN,  $SCMP_SYS{swapon}],
    [CAP_SYS_ADMIN,  $SCMP_SYS{swapoff}],
    [CAP_SYS_ADMIN,  $SCMP_SYS{open_by_handle_at}],
    [CAP_SYS_MODULE, $SCMP_SYS{init_module}],
    [CAP_SYS_MODULE, $SCMP_SYS{finit_module}],
    [CAP_SYS_MODULE, $SCMP_SYS{delete_module}],
    [CAP_SYSLOG,     $SCMP_SYS{syslog}],
], [
    # systemd-215/src/nspawn/nspawn.c
    # in systemd_215.orig.tar.xz with patches from systemd_215-17+deb8u13.debian.tar.xz
    # for Debian 8.11 on Linux (amd64, should be architecture-independent).
    # static const int blacklist[] = {...}.
    #
    # FYI no syscalls to enable here.
    [$SCMP_SYS{kexec_load}],
    [$SCMP_SYS{open_by_handle_at}],
    [$SCMP_SYS{init_module}],
    [$SCMP_SYS{finit_module}],
    [$SCMP_SYS{delete_module}],
    [$SCMP_SYS{iopl}],
    [$SCMP_SYS{ioperm}],
    [$SCMP_SYS{swapon}],
    [$SCMP_SYS{swapoff}],
]);

my %syscalls_to_enable = map { $SCMP_SYS{$_} => 1 } qw(add_key keyctl);  # For Docker.

sub serialize_blacklist($) {
  my $blacklist = $_[0];
  return "" if !@$blacklist;
  if (@{$blacklist->[0]} == 1) {  # C array of: int32_t syscall_num;
    return join("", map { die "$0: fatal: unknown syscall\n" if !defined($_->[-1]); pack("V", @$_) } @$blacklist);
  } else {  # C array of: uint64_t capability; int32_t syscall_num; uint32_t zeropad;
    return join("", map { die "$0: fatal: unknown syscall\n" if !defined($_->[-1]); pack("Vx4Vx4", @$_) } @$blacklist);
  }
}

sub get_blacklist_data($) {
  my $fn = $_[0];
  for my $blacklist (@blacklists) {
    my $data = serialize_blacklist($blacklist);
    my $i = index($_, $data);
    next if $i < 0;
    die "$0: fatal: multiple blacklists found\n" if index($_, $data, $i + 1) >= 0;
    return ($blacklist, $i);
  }
  # Return an empty blacklist if systemd-nspawn was compiled without HAVE_SECCOMP.
  # This check works with systemd 215.
  return ([], 0) if !(m@Failed to add audit seccomp rule@ and
                      m@Failed to install seccomp audit filter: %@);
  die "$0: fatal: blacklist not found: $fn\n";
}

my $fn = $ARGV[0];
{ die "$0: fatal: open: $fn: $!\n" if !open(my($f), "<", $fn);
  local $/ = undef;
  $_ = <$f>;
  die "$0: fatal: read: $fn: $!\n" if !defined($_);  # Can it happen?
  die "$0: fatal: close: $fn: $!\n" if !close($f);
}
my($blacklist, $i) = get_blacklist_data($fn);
# Enable a syscall by replacing the syscall number with -1 in the blacklist.
my @blacklistb = map { exists($syscalls_to_enable{$_->[1]}) ? [@$_[0 .. $#$_ - 1], -1] : $_ } @$blacklist;
my $data = serialize_blacklist(\@blacklistb);
substr($_, $i, length($data)) = $data;
my $fn2 = $ARGV[1];
unlink($fn2);  # Avoid ``Text file busy'' error.
{ die "$0: fatal: open for write: $fn2: $!\n" if !open(my($f), ">", $fn2);
  die "$0: fatal: chmod: $fn2: $!\n" if !chmod(0755, $fn2);
  die "$0: fatal: write: $fn2: $!\n" if !print($f $_);
  die "$0: fatal: close: $fn2: $!\n" if !close($f);
}

package lapi;

# Global / SystemLevel Modules
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Log::Log4perl ( qw( :easy ) );
use Monitoring::Livestatus;

setting log4perl => {
 tiny => 0,
 config => '
  log4perl.logger                      = DEBUG, OnFile, OnScreen
  log4perl.appender.OnFile             = Log::Log4perl::Appender::File
  log4perl.appender.OnFile.filename    = /var/log/livestatus-api/lapi.log
  log4perl.appender.OnFile.mode        = append
  log4perl.appender.OnFile.layout      = Log::Log4perl::Layout::PatternLayout
  log4perl.appender.OnFile.layout.ConversionPattern = [%d] [%5p] %m%n
  log4perl.appender.OnScreen           = Log::Log4perl::Appender::ScreenColoredLevels
  log4perl.appender.OnScreen.color.ERROR = bold red
  log4perl.appender.OnScreen.color.FATAL = bold red
  log4perl.appender.OnScreen.color.OFF   = bold green
  log4perl.appender.OnScreen.Threshold = ERROR
  log4perl.appender.OnScreen.layout    = Log::Log4perl::Layout::PatternLayout
  log4perl.appender.OnScreen.layout.ConversionPattern = [%d] >>> %m%n
 ',
};
setting logger => 'log4perl';

prepare_serializer_for_format;

our $VERSION = '0.2';

sub fetch_query {
  my ( $payload, $server ) = (@_);
  if ( defined( $server ) ) {
    my $servers;
    push( @{ $servers }, $server );
    my $ml = Monitoring::Livestatus->new(
      name          => "LAPI Connector",
      verbose       => 0,
      keepalive     => 1,
      peer          => $servers,
    );
    my $method = $payload->{meth};
    my $query = $payload->{query};
    my $opts = {};
    if (defined($payload->{opts})) {
      $opts = $payload->{opts};
    }
    my $stats = $ml->$method($query, $opts);
    return $stats;
  }
  else {
    my $stats;
    foreach my $key ( keys config->{livestatus_servers} ) {
      my $servers;
      my $tmp;
      $tmp->{name} = $key;
      $tmp->{peer} = config->{livestatus_servers}->{$key};
      push( @{ $servers }, $tmp);
      my $ml = Monitoring::Livestatus->new(
        name          => "LAPI Connector",
        verbose       => 0,
        keepalive     => 1,
        peer          => $servers,
      );
      my $method = $payload->{meth};
      my $query = $payload->{query};
      my $opts = {};
      if (defined($payload->{opts})) {
        $opts = $payload->{opts};
      }
      my $tmpstats = $ml->$method($query, $opts);
      foreach my $tmpstat ( @{$tmpstats} ) {
        push(@{$stats}, $tmpstat);
      }
    }
    return $stats;
  }
}

prefix '/lapi' => sub {

  any [ 'get', 'post' ] => '/' => \&info_routine;

  sub info_routine {
    set serializer => 'JSON';
    my $prefix = '/lapi/';
    my $locations;
    my @apilocations = (
      qw(
        columns services hosts servicegroups hostgroups
      )
    );
    for my $location ( @apilocations ) {
      push ( @{ $locations }, $prefix . $location );
    }
    return $locations;
  }; # /lapi

  any [ 'get', 'post' ] => '/columns.format' => \&columns_routine;
  any [ 'get', 'post' ] => '/columns' => \&columns_routine;

  sub columns_routine {
    if ( !defined( params->{format} ) ) {
      set serializer => 'JSON';
    }
    my $server = params->{server} || undef;
    my $query;
    $query->{query} = "GET columns\n";
    $query->{meth}  = "selectall_arrayref";
    $query->{opts}  = { Slice => {} };
    my $stats = fetch_query($query, $server);
    return $stats;
  }; # /lapi/columns

  any [ 'get', 'post' ] => '/hosts.format' => \&hosts_routine;
  any [ 'get', 'post' ] => '/hosts' => \&hosts_routine;

  sub hosts_routine {
    if ( !defined( params->{format} ) ) {
      set serializer => 'JSON';
    }
    my $server = params->{server} || undef;
    my $query = {
      'query' => "GET hosts\nColumns: name address state groups\n",
      'meth'  => "selectall_hashref",
      'opts'  => "name",
    };
    my $stats = fetch_query($query, $server);
    return $stats;
  }; # /lapi/hosts

  any [ 'get', 'post' ] => '/services.format' => \&services_routine;
  any [ 'get', 'post' ] => '/services' => \&services_routine;

  sub services_routine {
    if ( !defined( params->{format} ) ) {
      set serializer => 'JSON';
    }
    my $server = params->{server} || undef;
    my $query = {
      'query' => "GET services\nColumns: description host_name as name host_address as address state plugin_output as output\n",
      'meth'  => "selectall_arrayref",
      'opts'  => { Slice => {} },
    };
    my $stats = fetch_query($query, $server);
    return $stats;
  }; # /lapi/services

  any [ 'get', 'post' ] => '/hostgroups.format' => \&hostgroups_routine;
  any [ 'get', 'post' ] => '/hostgroups' => \&hostgroups_routine;

  sub hostgroups_routine {
    if ( !defined( params->{format} ) ) {
      set serializer => 'JSON';
    }
    my $server = params->{server} || undef;
    my $query = {
      'query' => "GET hostgroups\nColumns: name members num_hosts_up as up num_hosts_down as down num_hosts_pending as pending\n",
      'meth'  => "selectall_hashref",
      'opts'  => 'name',
    };
    my $stats = fetch_query($query, $server);
    return $stats;
  }; # /lapi/services

  any [ 'get', 'post' ] => '/servicegroups.format' => \&servicegroups_routine;
  any [ 'get', 'post' ] => '/servicegroups' => \&servicegroups_routine;

  sub servicegroups_routine {
    if ( !defined( params->{format} ) ) {
      set serializer => 'JSON';
    }
    my $server = params->{server} || undef;
    my $query = {
      'query' => "GET servicegroups\nColumns: name members num_services_hard_ok as oks num_services_hard_warn as warnings num_services_hard_crit as criticals num_services_hard_unknown as unknowns num_services_pending as pending\n",
      'meth'  => "selectall_hashref",
      'opts'  => 'name',
    };
    my $stats = fetch_query($query, $server);
    return $stats;
  }; # /lapi/servicegroups

  any [ 'get', 'post' ] => '/rawquery.format' => \&rawquery_routine;
  any [ 'get', 'post' ] => '/rawquery' => \&rawquery_routine;

  sub rawquery_routine {
    if ( !defined( params->{format} ) ) {
      set serializer => 'JSON';
    }
    my $params = params;
    my $server = params->{server} || undef;
    my $query;
    if (!defined($params->{query})) {
      send_error(
        {
          error => "Unable to detect query parameter to pass to servers",
        },
        401
      );
    }
    else {
      $query->{query} = $params->{query};
    }
    if (!defined($params->{meth})) {
      $query->{meth} = "selectall_arrayref";
      $query->{opts} = { Slice => {} };
    }
    else {
      $query->{meth} = $params->{meth};
      if (defined($params->{opts})) {
        $query->{opts} = $params->{opts};
      }
    }
    my $stats = fetch_query($query, $server);
    if ($params->{ui}) {
      my $fields;
      foreach my $datapoint (@{$stats}) {
        foreach my $key ( keys %{$datapoint} ) {
          if (!grep $key eq $_, @$fields) {
            push (@{$fields}, $key);
          }
        }
      }
      if ($params->{ui} eq 'service') {
        return template 'svc_table', {
          fields => $fields,
          data => $stats
        };
      }
      elsif ($params->{ui} eq 'host') {
        return template 'host_table', {
          fields => $fields,
          data => $stats
        };
      }
      else {
        return $stats;
      }
    }
    return $stats;
  }; # /lapi/rawquery

}; # /lapi prefix

any qr{.*} => sub {
    status 'not_found';
    template 'special_404', { path => request->path };
};

true;

%%%-------------------------------------------------------------------
%% @doc sipcall top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(sipcall_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 60
    },
    ChildSpecs = [
        nksip:get_sup_spec(sip_server, #{
            sip_local_host => "localhost",
            plugins => [nksip_registrar],
            sip_listen => "sip:all:5060"
        }),
        nksip:get_sup_spec(sip_client, #{
            sip_local_host => "localhost",
            sip_from => "sip:sip_client@127.0.0.1",
            plugins => [nksip_uac_auto_auth],
            sip_listen => "sip:127.0.0.1:5075"
        })
    ],
    io:format("sipcall_sup: ChildSpecs ~p~n", [ChildSpecs]),
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions

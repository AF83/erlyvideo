%%% @author     Max Lapshin <max@maxidoors.ru> [http://erlyvideo.org]
%%% @copyright  2009 Max Lapshin
%%% @doc        Endless http FLV streams registrator
%%% @reference  See <a href="http://erlyvideo.org/" target="_top">http://erlyvideo.org/</a> for more information
%%% @end
%%%
%%% This file is part of erlyvideo.
%%% 
%%% erlyvideo is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU General Public License as published by
%%% the Free Software Foundation, either version 3 of the License, or
%%% (at your option) any later version.
%%%
%%% erlyvideo is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with erlyvideo.  If not, see <http://www.gnu.org/licenses/>.
%%%
%%%---------------------------------------------------------------------------------------
-module(ems_flv_streams).
-author('Max Lapshin <max@maxidoors.ru>').
-behaviour(gen_server).

-record(flv_streams, {
  streams = []
}).

%% External API
-export([start_link/0, register/2, stream/1, command/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).



start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%--------------------------------------------------------------------
%% @spec (Name) -> undefined | {ok,Pid::pid()}
%%
%% @doc Find stream by name
%% @end
%%----------------------------------------------------------------------
stream(Name) ->
  gen_server:call(?MODULE, {stream, Name}).


%%--------------------------------------------------------------------
%% @spec (Name,Command) -> undefined|Command
%%
%% @doc Send command to stream if exists
%% @end
%%----------------------------------------------------------------------
command(Name,Command) ->
  case stream(Name) of
    undefined -> undefined;
    {ok, Pid, Client} -> Pid ! {Command, Client}
  end.


%%--------------------------------------------------------------------
%% @spec (Name,Pid) -> ok
%%
%% @doc register stream under Name
%% @end
%%----------------------------------------------------------------------
register(Name, Pid) ->
  gen_server:call(?MODULE, {register, Name, Pid}).



%%%------------------------------------------------------------------------
%%% Callback functions from gen_server
%%%------------------------------------------------------------------------

%%----------------------------------------------------------------------
%% @spec (Port::integer()) -> {ok, State}           |
%%                            {ok, State, Timeout}  |
%%                            ignore                |
%%                            {stop, Reason}
%%
%% @doc Called by gen_server framework at process startup.
%%      Create listening socket.
%% @end
%%----------------------------------------------------------------------


init([]) ->
  {ok, #flv_streams{}}.

%%-------------------------------------------------------------------------
%% @spec (Request, From, State) -> {reply, Reply, State}          |
%%                                 {reply, Reply, State, Timeout} |
%%                                 {noreply, State}               |
%%                                 {noreply, State, Timeout}      |
%%                                 {stop, Reason, Reply, State}   |
%%                                 {stop, Reason, State}
%% @doc Callback for synchronous server calls.  If `{stop, ...}' tuple
%%      is returned, the server is stopped and `terminate/2' is called.
%% @end
%% @private
%%-------------------------------------------------------------------------

handle_call({register, Name, Pid}, _From, #flv_streams{streams = Streams} = Server) ->
  erlang:monitor(process, Pid),
  {reply, ok, Server#flv_streams{streams = lists:keystore(Name, 1, Streams, {Name, Pid})}};

handle_call({stream, Name}, _From, #flv_streams{streams = Streams} = Server) ->
  Reply = case proplists:get_value(Name, Streams) of
    undefined -> undefined;
    Pid -> {ok, Pid}
  end,
  {reply, Reply, Server};

handle_call(Request, _From, State) ->
  {stop, {unknown_call, Request}, State}.

%%-------------------------------------------------------------------------
%% @spec (Msg, State) ->{noreply, State}          |
%%                      {noreply, State, Timeout} |
%%                      {stop, Reason, State}
%% @doc Callback for asyncrous server calls.  If `{stop, ...}' tuple
%%      is returned, the server is stopped and `terminate/2' is called.
%% @end
%% @private
%%-------------------------------------------------------------------------
handle_cast(_Msg, State) ->
  {stop, {unknown_cast, _Msg}, State}.

%%-------------------------------------------------------------------------
%% @spec (Msg, State) ->{noreply, State}          |
%%                      {noreply, State, Timeout} |
%%                      {stop, Reason, State}
%% @doc Callback for messages sent directly to server's mailbox.
%%      If `{stop, ...}' tuple is returned, the server is stopped and
%%      `terminate/2' is called.
%% @end
%% @private
%%-------------------------------------------------------------------------
handle_info({'DOWN', _, process, Client, _Reason}, #flv_streams{streams = Streams} = Server) ->
  {noreply, Server#flv_streams{streams = lists:keydelete(Client, 2, Streams)}};

handle_info(_Info, State) ->
  {noreply, State}.

%%-------------------------------------------------------------------------
%% @spec (Reason, State) -> any
%% @doc  Callback executed on server shutdown. It is only invoked if
%%       `process_flag(trap_exit, true)' is set by the server process.
%%       The return value is ignored.
%% @end
%% @private
%%-------------------------------------------------------------------------
terminate(_Reason, _State) ->
  ok.

%%-------------------------------------------------------------------------
%% @spec (OldVsn, State, Extra) -> {ok, NewState}
%% @doc  Convert process state when code is changed.
%% @end
%% @private
%%-------------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

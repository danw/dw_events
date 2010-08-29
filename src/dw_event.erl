%%%-------------------------------------------------------------------
%%% File    : dw_event.erl
%%% Author  : Dan Willemsen <dan@csh.rit.edu>
%%% Purpose : 
%%%
%%%
%%% edrink, Copyright (C) 2010 Dan Willemsen
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%                         
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%-------------------------------------------------------------------

-module (dw_event).
-behaviour (gen_server).

-export ([start_link/2]).
% gen_server API
-export ([init/1, terminate/2, code_change/3]).
-export ([handle_call/3, handle_cast/2, handle_info/2]).
% external-ish API
-export ([send_event/2, register_pid/3, unregister_pid/2, registered_name/1, set_permission_module/2]).

-record (state, {event_module, permission_module, watchers = []}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%
% External-ish API
%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_event (EventModule, Event) ->
    gen_server:call(registered_name(EventModule), {send, Event}).

register_pid (EventModule, Pid, ClientInfo) ->
    gen_server:call(registered_name(EventModule), {register, Pid, ClientInfo}).

unregister_pid (EventModule, Pid) ->
    gen_server:call(registered_name(EventModule), {unregister, Pid}).

set_permission_module (EventModule, PermissionModule) ->
    gen_server:call(registered_name(EventModule), {permissions, PermissionModule}).

registered_name (EventModule) ->
    list_to_atom("dw_event_" + atom_to_list(EventModule)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Internal API
%%%%%%%%%%%%%%%%%%%%%%%%%%%
start_link (EventModule, PermissionModule) when is_atom(EventModule), is_atom(PermissionModule) ->
	gen_server:start_link({local, registered_name(EventModule)}, ?MODULE, {EventModule, PermissionModule}, []).

init ({EventModule, PermissionModule}) ->
    {ok, #state{ event_module = EventModule, permission_module = PermissionModule }}.

terminate (_Reason, _State) ->
    ok. % TODO: Should probably do something here

code_change (_OldVsn, State, _Extra) ->
    {ok, State}.

handle_cast (_Request, State) -> {noreply, State}.

handle_call ({register, Pid, ClientInfo}, _From, State) ->
    {Response, NewState} = i_register_pid(Pid, ClientInfo, State),
    {reply, Response, NewState};
handle_call ({unregister, Pid}, _From, State) ->
    {Response, NewState} = i_unregister_pid(Pid, State),
    {reply, Response, NewState};
handle_call ({send, Event}, _From, State) ->
    {Response, NewState} = i_send(Event, State),
    {reply, Response, NewState};
handle_call ({permissions, PermissionModule}, _From, State) ->
    % TODO: run all existing watchers through can_register?
    {reply, ok, State#state{ permission_module = PermissionModule }};
handle_call (_Request, _From, State) -> {noreply, State}.

% TODO: implement exit watching / monitoring
handle_info ({'EXIT', _, _}, State) -> {noreply, State};
handle_info (_Info, State) -> {noreply, State}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Internal Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%
i_register_pid(Pid, Client, State = #state{ permission_module = PM }) when PM =/= undefined ->
    % TODO: check if Pid is already a watcher?
    case PM:can_register(State#state.event_module, Client) of
        ok ->
            i_register_watcher({Pid, Client}, State);
        Error ->
            {{error, Error}, State}
    end;
i_register_pid(Pid, Client, State) ->
    i_register_watcher({Pid, Client}, State).

i_register_watcher(Watcher = {_Pid, _}, State) ->
    % TODO: Monitor PID
    % TODO: Check to see if PID is alive
    NewWatchers = State#state.watchers ++ [Watcher],
    {ok, State#state{ watchers = NewWatchers }}.

i_unregister_pid(Pid, State) ->
    % TODO: Unmonitor Pid
    NewWatchers = proplists:delete(Pid, State#state.watchers),
    {ok, State#state{ watchers = NewWatchers }}.

% Send a message while filtering it through a permission module
% TODO: we may want it to filter and send individually instead of collecting all messages, then sending
i_send(Event, State = #state{ permission_module = PM }) when PM =/= undefined ->
    Messages = [ {Pid, PM:filter_event(State#state.event_module, Event, ClientInfo)} || {Pid, ClientInfo} <- State#state.watchers ],
    [ Pid ! {dw_event, State#state.event_module, Message} || {Pid, {ok, Message}} <- Messages ],
    {ok, State};

% Version without a permission module installed
i_send(Event, State) ->
    [ Pid ! {dw_event, State#state.event_module, Event} || {Pid, _} <- State#state.watchers ],
    {ok, State}.


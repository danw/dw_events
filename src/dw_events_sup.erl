%%%-------------------------------------------------------------------
%%% File    : dw_events_sup.erl
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

-module (dw_events_sup).
-behaviour (supervisor).

% supervisor calls
-export ([start_link/1, init/1]).
% API
-export ([register_module/2, register_pid/3, unregister_pid/2, send_event/3]).

start_link (Args) ->
    supervisor:start_link({local,?MODULE}, ?MODULE, Args).

init ([]) ->
    {ok, {{simple_one_for_one, 1, 1},
        [{dw_event,
          {dw_event, start_link, []},
          permanent,
          100,
          worker,
          [dw_event]}]}}.

% TODO: only do the EventModule -> atom lookup once

register_module (EventModule, PermissionModule) ->
    case module_running(EventModule) of
        true -> dw_event:set_permission_module(EventModule, PermissionModule);
        false -> supervisor:start_child(?MODULE, [EventModule, PermissionModule])
    end.

register_pid (EventModule, Pid, ClientInfo) ->
    ensure_module_running(EventModule),
    dw_event:register_pid(EventModule, Pid, ClientInfo).

unregister_pid (EventModule, Pid) ->
    case module_running(EventModule) of
        true -> dw_event:unregister_pid(EventModule, Pid);
        _ -> ok
    end.

send_event (EventModule, Pid, Event) ->
    ensure_module_running(EventModule),
    dw_event:send_event(EventModule, Pid, Event).

ensure_module_running (EventModule) ->
    case module_running(EventModule) of
        true -> ok;
        false ->
            register_module(EventModule, undefined)
    end.

module_running (EventModule) ->
    Children = [ process_info(Pid, registered_name) || {_, Pid, _, _} <- supervisor:which_children(?MODULE) ],
    lists:member(dw_event:registered_name(EventModule), Children).

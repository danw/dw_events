%%%-------------------------------------------------------------------
%%% File    : dw_events.erl
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

-module (dw_events).

-export ([register_module/1, register_module/2, register_pid/2, unregister_pid/1, send/2]).

register_module (EventModule) when is_atom(EventModule) ->
    register_module(EventModule, undefined).

register_module (EventModule, PermissionModule) when is_atom(EventModule), is_atom(PermissionModule) ->
    dw_events_sup:register_module(EventModule, PermissionModule).

register_pid (EventModule, {registered, RegisteredName}) when is_atom(RegisteredName)->
    case process_info(self(), registered_name) of
        {registered_name, RegisteredName} ->
            dw_events_sup:register_pid(EventModule, self(), {registered, RegisteredName});
        _ ->
            {error, permission_denied}
    end;
register_pid (_EventModule, {registered, _}) -> {error, client_info_invalid};
register_pid (EventModule, ClientInfo) ->
    dw_events_sup:register_pid(EventModule, self(), ClientInfo).

unregister_pid (EventModule) ->
    dw_events_sup:unregister_pid(EventModule, self()).

send (EventModule, Event) ->
    dw_events_sup:send_event(EventModule, self, Event).

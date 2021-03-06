%% =====================================================================
%% Licensed under the Apache License, Version 2.0 (the "License"); you may
%% not use this file except in compliance with the License. You may obtain
%% a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% Alternatively, you may use this file under the terms of the GNU Lesser
%% General Public License (the "LGPL") as published by the Free Software
%% Foundation; either version 2.1, or (at your option) any later version.
%% If you wish to allow use of your version of this file only under the
%% terms of the LGPL, you should delete the provisions above and replace
%% them with the notice and other provisions required by the LGPL; see
%% <http://www.gnu.org/licenses/>. If you do not delete the provisions
%% above, a recipient may use your version of this file under the terms of
%% either the Apache License or the LGPL.
%%
%% @copyright 2019 Radek Szymczyszyn
%% @author Radek Szymczyszyn <lavrin@gmail.com>
%% @end
%% =====================================================================

%% @doc Doclet generating standalone EEP-48 Docs chunk files.
%% @reference See http://erlang.org/eeps/eep-0048.html.
%% @end

%% Note that this is written so that it is *not* depending on edoc.hrl!

-module(edoc_doclet_chunks).

-export([run/2]).

-import(edoc_report, [report/2, warning/2]).

%% @headerfile "../include/edoc_doclet.hrl"
-include("../include/edoc_doclet.hrl").

-define(DEFAULT_FILE_SUFFIX, ".chunk").
-define(CHUNKS_DIR, "chunks").

-include_lib("xmerl/include/xmerl.hrl").

-spec run(edoc_doclet:command(), edoc_doclet:context()) -> ok.
run(#doclet_gen{} = Cmd, Ctxt) ->
    gen(Cmd#doclet_gen.sources,
	Cmd#doclet_gen.app,
	Cmd#doclet_gen.modules,
	Ctxt);
run(#doclet_toc{} = _Cmd, _Ctxt) ->
    erlang:error(not_implemented).
    %toc(Cmd#doclet_toc.paths, Ctxt).

gen(Sources, _App, Modules, Ctxt) ->
    Dir = filename:join(Ctxt#doclet_context.dir, ?CHUNKS_DIR),
    Env = Ctxt#doclet_context.env,
    Options = Ctxt#doclet_context.opts,
    case sources(Sources, Dir, Modules, Env, Options) of
	{_, true = _Error} -> exit(error);
	{_, false} -> ok
    end.


%% @doc Process the individual source files.

%% NEW-OPTIONS: file_suffix, private, hidden
%% INHERIT-OPTIONS: edoc:layout/2
%% INHERIT-OPTIONS: edoc:get_doc/3
%% DEFER-OPTIONS: run/2

sources(Sources, Dir, Modules, Env, Options) ->
    Suffix = proplists:get_value(file_suffix, Options, ?DEFAULT_FILE_SUFFIX),
    Private = proplists:get_bool(private, Options),
    Hidden = proplists:get_bool(hidden, Options),
    {Ms, E} = lists:foldl(fun (Src, {Set, Error}) ->
				  source(Src, Dir, Suffix, Env, Set,
					 Private, Hidden, Error, Options)
			  end,
			  {sets:new(), false}, Sources),
    {[M || M <- Modules, sets:is_element(M, Ms)], E}.


%% @doc Write a chunk file for a source file.
%%
%% Add its name to the set if it was successful.
%% Errors are just flagged at this stage,
%% allowing all source files to be processed even if some of them fail.
source({_M, Name, Path}, Dir, Suffix, _Env, OkSet, _Private, _Hidden, ErrorFlag, _Options) ->
    File = filename:join(Path, Name),
    try
	%% TODO: edoc_doclet_default does check_name, check for private, and check for hidden here
	Chunk = edoc_chunks:edoc_to_chunk(File),
	WriteOptions = [{encoding, utf8}],
	ok = write_file(term_to_binary(Chunk), Dir, chunk_file_name(Name, Suffix), WriteOptions),
	{sets:add_element(Name, OkSet), ErrorFlag}
    catch _:R:St ->
	report("skipping source file '~ts': ~tP.", [File, R, 15]),
	io:format("stacktrace:\n~p\n", [St]),
	{OkSet, true}
    end.

chunk_file_name(ErlName, Suffix) ->
    string:join([filename:basename(ErlName, ".erl"), Suffix], "").

write_file(Data, Dir, Name, _Options) ->
    File = filename:join([Dir, Name]),
    ok = filelib:ensure_dir(File),
    case file:write_file(File, Data) of
	ok -> ok;
	{error, R} ->
	    R1 = file:format_error(R),
	    report("could not write file '~ts': ~ts.", [File, R1]),
	    exit(error)
    end.

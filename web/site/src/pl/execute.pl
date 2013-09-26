:- module(execute,
	  [
	   do_plan_in_thread/2,
	   plan_license_entries/2,
	   plan_config_entries/2,
	   done_so_far/1
	  ]).

%
%   Execute the plan
%

:- use_module(library(http/http_open)).
:- use_module(bundle).
:- use_module(coginstall, [server_port/1]).
:- use_module(logger).

% this is the html
:- dynamic
	current_progress_data/1.

:- initialization
	mutex_create(progress).

% TODO make this handle errors gracefully
do_plan_in_thread(Plan, Config) :-
	make_directories_exist(Config),
	retractall(current_progress_data(_)),
	assert(current_progress_data([])),
	thread_create(do_plan(Plan, Config),
		      _,
		      [
		       alias(plan_execution_thread),
		       at_exit(execute:execution_done),
		       detached(true)]).

execution_done :-
	append_progress(finished).

done_so_far(NamesDone) :-
	with_mutex(progress, current_progress_data(NamesDone)).

append_progress(Item) :-
	with_mutex(progress, append_progress_core(Item)).

% famulus for append_progress - nobody else call
append_progress_core(Item) :-
	current_progress_data(SoFar),
	append(SoFar, Item, New),
	retractall(current_progress_data(_)),
	assert(current_progress_data(New)).

do_plan([], _).

do_plan([Name|T], Config) :-
	bundle(Name, Type, _, _),
	memberchk(Type, [group, license, licensepage, config, configpage]),
	do_plan(T,  Config).

do_plan([Name|T],  Config) :-
	bundle(Name, files, _, Args),
	memberchk(from(From), Args),
	memberchk(to(To), Args),
	id_abs_path(From, Config, FromAbs),
	id_abs_path(To, Config, ToAbs),
	exists_file(FromAbs),
	file_unzip(FromAbs, ToAbs),   % blocks
	do_plan(T,  Config).

do_plan([Name|T],  Config) :-
	bundle(Name, files, _, Args),
	memberchk(from(From), Args),
	id_abs_path(From, Config, FromAbs),
	\+ exists_file(FromAbs),
	memberchk(url(URL), Args),
	id_abs_path(URL, Config, RealURL),
	file_download(RealURL, FromAbs),   % blocks
	do_plan([Name|T],  Config).

do_plan([Name|T],  Config) :-
	bundle(Name, page, _, Args),
	memberchk(url(Page), Args),
	www_open_url(Page),
	logger(message , 'Waiting for continue(_) on answer', []),
	thread_get_message(answer, continue(Name), [timeout(1.0)]),
	logger(message , 'Heard continue(~w) on answer~n', [Name]),
	do_plan(T,  Config).

file_download(URL, File) :-
	setup_call_cleanup(
	    open(File, write, Out, [type(binary)]),
	    (
                http_open(URL, In, []),
		copy_stream_data(In, Out)
	    ),
	    close(In)).

file_unzip(From, To) :-
	format(string(S), 'unzip.exe -o "~w" "~w"~n', [From, To]),
	shell(S).


%%	%%%%%%%%%%%%%%%%% Convert symbolic to absolute paths
%
%	converts a symbolic to an absolute path in the install
%	These are path names in the os native
%	typical use
%
%bundle(core, files,
%       'Cogbot Core',
%       [from(temp('cogbot-core.zip')),
%	url(logicmoo('cogbot-core.zip')),
%	to(program(unzip))]).
%
%	known symbols
%	temp(X)  X is a relative path not starting with \ from the
%	         Cogbot Install Files directory
%
%	program(X) X is a relative path from the program install
%	           directory  (eg. C:\Program Files\Cogbot\
%	           X should not start with \
%
%	logicmoo(X) X is a relative path from the uri where
%	            the file can be found.

id_abs_path(Symbol, _Config, Symbol) :-
	atomic(Symbol).

id_abs_path(temp(Symbol), Config, Out) :-
	memberchk(temp=Loc, Config),
	trailing_backslash(Loc, NLoc),
	atom_concat(NLoc, Symbol, Out).

id_abs_path(temp(Symbol), _Config, Out) :-
	atom_concat('C:\\Cogbot\\', Symbol, Out).

id_abs_path(program(Symbol), Config, Out) :-
	memberchk(install=Loc, Config),
	trailing_backslash(Loc, NLoc),
	atom_concat(NLoc, Symbol, Out).

id_abs_path(program(Symbol), _Config, Out) :-
	atom_concat('C:\\Program Files\\Cogbot\\', Symbol, Out).

id_abs_path(logicmoo(Symbol), _Config, Out) :-
	atom_concat('http://cogbot.logicmoo.com/install/cogbot/' ,
		    Symbol, Out).

trailing_backslash(Path, Path) :-
	atom_concat(_, \, Path).

trailing_backslash(Path, PathEndingInSlash) :-
	atom_concat(Path, \, PathEndingInSlash).

make_directories_exist(Config) :-
	make_directories_exist(Config, [temp, program]).

make_directories_exist(_, []).
make_directories_exist(Config, [H|T]) :-
	Symbol =.. [H, ''],
	id_abs_path(Symbol, Config, Path),
	prolog_to_os_filename(PathPL, Path),
	make_directory_path(PathPL),
	make_directories_exist(Config, T).

%%	%%%%%%%%%%%%%%%%%%%%%%%% Extract License Info  %%%%%%%%%%
%

%   Given a plan, make the corresponding licenseHTML
%  plan_license_entries(+Plan, -LicenseHTML)
%
plan_license_entries([], []).

plan_license_entries([Name|_] , []) :-
	bundle(Name, licensepage, _, _).

plan_license_entries([Name|T] ,
		     [\license_entry(Title, URL)| LicenseHTML]) :-
	bundle(Name, license, Title, Args),
	memberchk(url(URL), Args),
	plan_license_entries(T, LicenseHTML).

plan_license_entries([Name|T] , LicenseHTML) :-
	bundle(Name, Type, _, _),
	Type \= license,
	Type \= licensepage,
	plan_config_entries(T, LicenseHTML).


%%	%%%%%%%%%%%%%%%%%%%%%%%% Extract Config Info  %%%%%%%%%%
%

%   Given a plan, make the corresponding ConfigHTML
%  plan_config_entries(+Plan, -ConfigHTML)
%
plan_config_entries([], []).

plan_config_entries([Name|_] , []) :-
	bundle(Name, configpage, _, _).

plan_config_entries([Name|T] ,
		     [\config_entry(Title, html(Stuff))| ConfigHTML]) :-
	bundle(Name, config, Title, Args),
	(
	    memberchk(inc(Stuff), Args)
	;
	    Stuff = [p(blink('Missing inc in bundle'))]
	),
	plan_config_entries(T, ConfigHTML).

plan_config_entries([Name|T] , ConfigHTML) :-
	bundle(Name, Type, _, _),
	Type \= config,
	Type \= configpage,
	plan_config_entries(T, ConfigHTML).



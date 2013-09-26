:- module(pages, [
		  wizard_page//0,
		  null_request/1,
		  reset_installer/0,
		  set_architecture/2,
		  license_accepted_request/1,
		  reset_install_request/1,
		  components_selected_request/1,
		  architecture/1,
		  do_request/1
		 ]).

% TODO depressingly, it looks like I'm retaining all the
% assert/retracts during the great renaiming.
%
% dynamics still being used:
% architecture/1
% the selected set of components
%
% I think components_selected_request is dead
%

%%	%%%%%%%%%%%%%%%%%%  OLD STUFF
%
%  Generate the content of the pages for the installer
%  There's only a single handler that displays the page.
%  That page decides what content to display based on the
%  current install state.
%
%  All actions do the actual act, then redirect to the single
%  display page.
:- multifile wizard_page_title/2,
	wizard_page_content/2,
	wizard_page_actions/2.

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(component).
:- use_module(bundle).
:- use_module(execute).
:- use_module(startpage).
:- use_module(coglicense).
:- use_module(logger).
:- use_module(configpage).
:- use_module(componentspage).

:-dynamic license_accepted/0,
	plan_accepted/0,
	start_seen/0,
	components_accepted/0,
	architecture/1.

:- discontiguous next_wizard_page/2, wizard_page_title/2.
:- discontiguous wizard_page_content/2, wizard_page_actions/2.

:- multifile next_wizard_page/2, wizard_page_title/2.
:- multifile wizard_page_content/2, wizard_page_actions/2.

%%%%%%%%%%%%%%%
%   template selection
%%%%%%%%%%%%%%%

% pages are built on templates.
% the arg unifies with the current template to use.
% Yep, this is perty poorly done.
%
current_wizard_page(configpage) :-
	license_accepted.

current_wizard_page(license) :-
	plan_accepted.

current_wizard_page(install_list) :-
	components_accepted.

current_wizard_page(components) :-
	start_seen.

current_wizard_page(start).

reset_installer :-
	retractall(license_accepted),
	retractall(start_seen),
	retractall(components_accepted),
	retractall(architecture(_)),
	retractall(plan_accepted),
	assert(architecture(64)).

architecture(64).

%%%%%%%%%%%%%
%  Requests - verbs that cause actions
%%%%%%%%%%%%%

null_request(_Request).

set_architecture(Architecture, _Request) :-
	start_seen, !,
	retractall(architecture(_)),
	assert(architecture(Architecture)).

set_architecture(Architecture, _Request) :-
       assert(start_seen),
	retractall(architecture(_)),
	assert(architecture(Architecture)).

license_accepted_request(_Request) :- license_accepted.
license_accepted_request(_Request) :-
	assert(license_accepted),
	logger(message,
	       'execute:license_accepted_request sending licenseok on answer',
	       []),
	thread_send_message(answer, licenseok),
	logger(message,
	     'execute:license_accepted_request sent licenseok on answer' , []).

components_selected_request(_Request) :- components_accepted.
components_selected_request(_Request) :-
	assert(components_accepted).


reset_install_request(_Request) :- reset_installer.

do_request(_Request) :-
	assert(plan_accepted),
	bundle_install_plan(Plan),
	catch(message_queue_destroy(progress), _,
	      format(user_error, 'Cannot destroy queue progress~n', [])),
	catch(message_queue_destroy(answer), _,
	      format(user_error, 'Cannot destroy queue answer~n', [])),
	message_queue_create(progress),   % coming to this thread
	message_queue_create(answer),  % answers to plan_runner_thread
	thread_create(do_plan(Plan), _,
		      [alias(plan_runner_thread), detached(true)]).



%%%%%%%%%%%%%%%%%%%%
%   Template data
%%%%%%%%%%%%%%%%%%%%

%
%  install_list   the list of what bundles will be installed
%
wizard_page_title(install_list, 'These Actions Will Be Taken').
wizard_page_content(install_list, pages:install_list_page_content).

wizard_page_actions(install_list, [
				   \wizard_button(reset, 'Cancel The Installation'),
				  \wizard_button_default(do,
							 'Take These Actions')]).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Assemble the actual contents
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

wizard_page -->
	{
	    current_wizard_page(Name),
	    wizard_page_title(Name, PageTitle),
	    wizard_page_content(Name, Content),
	    wizard_page_actions(Name, Actions)
	},
	html([
	    h2(PageTitle),
	    \Content,
	    \action_bar(Actions)
        ]).


%%
%%  wings_toolbar.erl --
%%
%%     Toolbar for geometry and AutoUV windows.
%%
%%  Copyright (c) 2004-2016 Bjorn Gustavsson & Dan Gudmundsson
%%
%%  See the file "license.terms" for information on usage and redistribution
%%  of this file, and for a DISCLAIMER OF ALL WARRANTIES.
%%
%%     $Id$
%%

-module(wings_toolbar).

-export([init/3, update/2]).

-include("wings.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Toolbar

% If tool is usable (clickable) or not.
enable_tool(_, _, _) ->
% enable_tool(Toolbar, Id, State) ->
    ok.

% If the state is on/off.
toggle_tool(Toolbar, Id, State) ->
    Btn = wxWindow:findWindowById(Id, [{parent, Toolbar}]),
    wxButton:setBackgroundColour(Btn,
        case State of
            true -> {0, 255, 0};
            false -> {0, 0, 0}
        end
    ).

update({active, Win, Restr}, #{active:=Win, restr:=Restr}=St) ->
    St;
update({active, Win, Restr}, #{me:=TB, wins:=Wins}=St) ->
    case maps:get(Win, Wins, false) of
	false ->
	    update({active, geom, Restr}, St);
	{Mode,Sh} ->
	    update_selection(TB, Mode, Sh, Restr),
	    St#{mode:=Mode, sh:=Sh, active:=Win, restr=>Restr}
    end;
%% Always keep toogletools upto date
update({selmode, Win, Mode, Sh}, #{active:=Active, me:=TB, restr:=Restr, wins:=Wins}=St) ->
    case Active of
	Win ->
	    update_selection(TB, Mode, Sh, Restr),
	    St#{mode:=Mode, sh:=Sh, wins=>Wins#{Win=>{Mode, Sh}}};
	_ ->
	    St#{wins=>Wins#{Win=>{Mode, Sh}}}
    end;
update({mode_restriction, Restr}, #{me:=TB, mode:=Mode, sh:=Sh}=St) ->
    update_selection(TB, Mode, Sh, Restr),
    St#{restr:=Restr};
update({view, Key0, State}, #{me:=TB}=St) ->
    {Key, Value} = case Key0 of
		       {show, K} -> {K, State};
		       workmode -> {workmode, not State};
		       _ -> {Key0, State}
		   end,
    case wings_menu:predefined_item(toolbar, Key) of
	false -> ignore;
	Id -> toggle_tool(TB, Id, Value)
    end,
    St.

update_selection(TB, Mode, Sh, Restr) ->
    All = [vertex, edge, face, body],
    Enabled = button_restrict(All, Restr),
    States = [{Butt, wings_menu:predefined_item(toolbar, Butt),
	       Butt =:= Mode orelse button_sh_filter(Butt, Sh)}
	      || Butt <- All],
    [toggle_tool(TB, Id, State) || {_, Id, State} <- States],
    [enable_tool(TB, Id, lists:member(Butt, Enabled)) || {Butt, Id, _} <- States],
    case Restr of
	[One] -> [enable_tool(TB, Id, false) || {Butt, Id, _} <- States, Butt =:= One];
	_ -> ignore
    end.

button_restrict(Buttons, none) -> Buttons;
button_restrict(_Buttons, Restr) -> Restr.

button_sh_filter(_, false) -> false;
button_sh_filter(vertex, true) -> true;
button_sh_filter(edge, true) -> true;
button_sh_filter(face, true) -> true;
button_sh_filter(body, true) -> true;
button_sh_filter(_, _) -> false.

init(Frame, FrameSizer, Icons) ->
    wxSystemOptions:setOption("msw.remap", 2),

    TB = wxPanel:new(Frame),
    HSizer = wxBoxSizer:new(?wxHORIZONTAL),
    wxSizer:add(FrameSizer, TB, [{proportion, 0},
             {flag, ?wxEXPAND},
             {border, 0}]),

    wxPanel:setBackgroundColour(TB, {255, 0, 0}),

    Bs = [make_bitmap(B, Icons) || B <- buttons()],
    Tools = case wings_pref:get_value(extended_toolbar) of
		true -> Bs;
		false -> standard(Bs)
	    end,
    [add_tools(Tool, TB, HSizer) || Tool <- Tools],

    wxPanel:setSizer(TB, HSizer),

    State = #{me=>TB, mode=>body, sh=>false, restr=>none, bs=>Bs, active=>geom, wins=>#{}},
    update({selmode, geom, body, false}, State).

buttons() ->
    Os = os:type(),
    [make_button(open, normal, os(Os, "wxART_FILE_OPEN")),
     make_button(save, normal, os(Os, "wxART_FILE_SAVE")),
     make_button(undo, normal, os(Os, "wxART_UNDO")),
     make_button(redo, normal, os(Os, "wxART_REDO")),
     separator,
     make_button(body, toggle),
     make_button(vertex, toggle),
     make_button(edge, toggle),
     make_button(face, toggle),
     separator,
     make_button(pref, normal),
     make_button(workmode,toggle), make_button(orthogonal_view, toggle),
     make_button(show_groundplane, toggle), make_button(show_axes, toggle)].

os({unix, linux}, Art) -> Art;
os(_, Art) -> {fallback, Art}.

make_button(Name, Type) ->
    make_button(Name, Type, {fallback, undefined}).

make_button(Name, Type, Art) ->
    Id = wings_menu:predefined_item(toolbar, Name),
    true = is_integer(Id),
    #{name=>Name, id=>Id, art=>Art, type=>Type}.

standard(Bs) ->
    Standard = [workmode,orthogonal_view,separator,
		vertex,edge,face,body,separator,
		show_groundplane,show_axes],
    GetButton = fun(separator) -> separator;
		   (Name) -> wings_util:mapsfind(Name, name, Bs)
		end,
    [GetButton(Value) || Value <- Standard].

icon_name(workmode) -> smooth;
icon_name(orthogonal_view) -> perspective;
icon_name(show_groundplane) -> groundplane;
icon_name(show_axes) -> axes;
icon_name(Name) -> Name.

make_bitmap(#{name:=Name,art:={fallback, Art}}=B, Imgs) ->
    case lists:keyfind(icon_name(Name), 1, Imgs) of
        {_,_,Image} ->
            Bm = wxBitmap:new(Image),
            true = wxBitmap:ok(Bm),
            B#{bm=>Bm};
        false when Art =/= undefined ->
            make_bitmap(B#{art:=Art}, Imgs)
    end;
make_bitmap(#{art:=Art}=B, Images) ->
    BM = wxArtProvider:getBitmap(Art, [{client, "wxART_TOOLBAR"}]),
    case BM == ?wxNullBitmap of
	true -> %% Load our backup bitmap
	    make_bitmap(B#{art:={fallback,undefined}}, Images);
	false ->
	    B#{bm=>BM}
    end;
make_bitmap(separator, _Images) -> separator.

add_tools(separator, _, HSizer) ->
    wxSizer:addStretchSpacer(HSizer);

add_tools(#{id:=Id, bm:=BM, type:=Type, name:=Tool}, Toolbar, HSizer) ->
%     Kind = button_kind(Type),
    Help = button_help(Tool),
    Btn = wxBitmapButton:new(Toolbar, Id, BM),
    wxWindow:setToolTip(Btn, Help),
    wxEvtHandler:connect(Btn, command_button_clicked, [{callback, fun handle_button_click/2}, {userData, #{id => Id}}]),

    wxSizer:add(HSizer, Btn,  [
        {proportion, 0},
        {flag, ?wxALL bor ?wxALIGN_CENTER_VERTICAL},
        {border, 4}
    ]),

    enable_tool(Toolbar, Id, true),
    case Type of
        toggle when Tool =:= workmode ->
            toggle_tool(Toolbar, Id, not wings_pref:get_value(Tool, false));
        toggle ->
            toggle_tool(Toolbar, Id, wings_pref:get_value(Tool, false));
        _ ->
            ignore
    end,
    ok.

handle_button_click(#wx{obj=_, userData=#{id:=Id}}, _) ->
    wings ! {action, wings_menu:id_to_name(Id)}.

% button_kind(toggle) -> ?wxITEM_CHECK;
% button_kind(normal) -> ?wxITEM_NORMAL.

button_help(Tool) ->
    button_help_2(icon_name(Tool), undecided).

%button_help_2(vertex, vertex) -> ?__(1,"Select adjacent vertices");
button_help_2(vertex, _) ->  ?__(2,"Change to vertex selection mode");
%button_help_2(edge, edge) ->  ?__(3,"Select adjcacent edges");
button_help_2(edge, _) ->  ?__(4,"Change to edge selection mode");
%button_help_2(face, face) ->  ?__(5,"Select adjacent faces");
button_help_2(face, _) ->  ?__(6,"Change to face selection mode");
%button_help_2(body, body) -> "";
button_help_2(body, _) ->  ?__(7,"Change to body selection mode");
button_help_2(Button, _) -> button_help_3(Button).

button_help_3(groundplane) ->
    [hide(), ?__(6," or "), show(), " "|?STR(messages,groundplane,"ground plane")];
button_help_3(axes) ->
    [hide(), ?__(6," or "), show(), " "|?STR(messages,axes,"axes")];
button_help_3(perspective) ->
    [?STR(messages,change_between,"Change between")," ",
     ?STR(messages,orthogonal,"orthogonal view"), ?__(6," or "),
     ?STR(messages,perspective,"perspective view")];
button_help_3(smooth) ->
    [?STR(messages,show_objects,"Show objects with")," ",
     ?STR(messages,smooth,"smooth shading"), ?__(6," or "),
     ?STR(messages,flat,"flat shading")];

button_help_3(undo) -> ?__(1,"Undo the last command");
button_help_3(redo) -> ?__(2,"Redo the last command that was undone");
button_help_3(open) -> ?__(3,"Open a previously saved scene");
button_help_3(save) -> ?__(4,"Save the current scene");
button_help_3(pref) -> ?__(5,"Edit the preferences for Wings").

hide() -> ?STR(messages,hide,"Hide").
show() -> ?STR(messages,show,"Show").


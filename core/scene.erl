-module(scene).
-export([start/0, draw/2, render_options/2, render_message/3]).

start() ->
    {ok, Display} = display:start(),
    register(display, Display),
    {ok, Input} = input:start(),
    Scene = render_message(info, "pocketOS", "Hello."),
    draw(Display, Scene),
    GBEmu = open_port({spawn, "gbemu"}, []),

    UART = uart:open("UART0", []),
    loop(GBEmu, UART).

render_message(info, Title, Text) ->
    render_message(icons64:info_icon(), Title, Text);

render_message(critical, Title, Text) ->
    render_message(icons64:critical_icon(), Title, Text);

render_message(warning, Title, Text) ->
    render_message(icons64:warning_icon(), Title, Text);

render_message(Icon, Title, Text) ->
    [
        {clear_screen, 16#CE59},
        {rect, 0, 0, 320, 18, 16#0010},
        {text, 1, 1, Title, 16#FFFF},
        {image, 1, 80, Icon, 16#CE59},
        {text, 70, 103, Text, 16#00}
    ].

render_options(Options, Selected) ->
    render_options(Options, Selected, 0).

render_options([], _Selected, _Index) ->
    [];

render_options([Text | Options], Selected, Index) when Selected == Index ->
    [
        {rect, 0, 18 * Index, 320, 18, 16#0010},
        {text, 1, 18 * Index + 1, Text, 16#FFFF} |
        render_options(Options, Selected, Index + 1)
    ];

render_options([Text | Options], Selected, Index) ->
    BackColor =
        case Index rem 2 of
            0 -> 16#E73C;
            1 -> 16#D69A
        end,
    [
        {rect, 0, 18 * Index, 320, 18, BackColor},
        {text, 1, 18 * Index + 1, Text, 16#0000} |
        render_options(Options, Selected, Index + 1)
    ].

loop(GBEmu, UART) ->
    {ok, R} = uart:read(UART),
    erlang:display(R),
    Msg =
    case erlang:binary_to_list(R) of
            % Serial / simulation
            "s" -> {button, start, press};
            "e" -> {button, select, press};
            "a" -> {button, a, press};
            "b" -> {button, b, press};
            [27, 91, 68] -> {button, left, press};
            [27, 91, 65] -> {button, up, press};
            [27, 91, 67] -> {button, right, press};
            [27, 91, 66] -> {button, down, press};

            % Real hardware
            [16#FC, 16#00, 16#02, 16#00, 16#FE] -> {button, down, press};
            Any -> {none}
        end,
    erlang:display(ok),
    avm_gen_server:call(GBEmu, Msg, 60000),
    erlang:display(done),
    loop(GBEmu, UART).

draw(_Display, []) ->
    ok;

draw(Display, [{clear_screen, Color} | Tail]) ->
    display:clear_screen(Display, Color),
    draw(Display, Tail);

draw(Display, [{image, X, Y, Image, BackgroundColor} | Tail]) ->
    display:draw_image(Display, X, Y, Image, BackgroundColor),
    draw(Display, Tail);

draw(Display, [{rect, X, Y, W, H, Color} | Tail]) ->
    display:draw_rect(Display, X, Y, W, H, Color),
    draw(Display, Tail);

draw(Display, [{text, X, Y, Text, Color} | Tail]) ->
    display:draw_text(Display, X, Y, Text, Color),
    draw(Display, Tail).

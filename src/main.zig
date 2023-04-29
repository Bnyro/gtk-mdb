const std = @import("std");
const capy = @import("capy");

// https://image.tmdb.org/t/p/w500/8YFL5QQVPy3AgrEQxNYVSgiPEbe.jpg
// https://www.themoviedb.org/documentation/api/discover
// https://api.themoviedb.org/3/discover/movie?api_key=

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

var container: *capy.Container_Impl = undefined;

const string = []const u8;
const Result = struct {
    adult: bool,
    backdrop_path: string,
    genre_ids: []i64,
    id: i64,
    original_language: string,
    original_title: string,
    overview: string,
    popularity: f64,
    poster_path: string,
    release_date: string,
    title: string,
    video: bool,
    vote_average: f64,
    vote_count: i64,
};

const baseUrl = "https://api.themoviedb.org/3";
const imageUrl = "https://image.tmdb.org/t/p/w200";

const DiscoverResponse = struct { page: i64, total_pages: i64, total_results: i64, results: []Result };

// make a get request to the specified url, parse the json and return the encoded object
fn fetchJson(comptime T: type, url: string) anyerror!T {
    const uri = try std.Uri.parse(url);
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var req = try client.request(.GET, uri, .{ .allocator = allocator }, .{});
    defer req.deinit();
    try req.start();
    try req.wait();

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    var buffer: [1]u8 = undefined;
    while (true) {
        const read = try req.read(&buffer);

        if (read == 0) break;

        try list.append(buffer[0]);
    }

    var stream = std.json.TokenStream.init(list.items);
    return try std.json.parse(T, &stream, .{ .allocator = allocator, .ignore_unknown_fields = true });
}

fn addNullByte(str: string) [:0]u8 {
    return std.cstr.addNullByte(allocator, str) catch unreachable;
}

fn createEntry(movie: Result) void {
    // const posterUrl = std.fmt.allocPrint(allocator, "{s}{s}", .{ imageUrl, movie.poster_path }) catch return;
    // const image = capy.Image(.{ .url = posterUrl });

    const column = capy.Column(.{}, .{
        capy.Label(.{ .text = addNullByte(movie.title) }),
        capy.Label(.{ .text = addNullByte(movie.overview) }),
        capy.Row(.{}, .{
            capy.Label(.{ .text = addNullByte(movie.release_date) }),
            capy.Label(.{ .text = addNullByte(movie.original_language) }),
        }) catch unreachable,
    }) catch unreachable;
    const content = capy.Margin(capy.Rectangle.init(10, 10, 10, 10), column) catch unreachable;
    container.add(content) catch unreachable;
}

pub fn fetchDiscover() anyerror!void {
    const apiKey = std.os.getenv("TMDB_KEY").?;
    const url = try std.fmt.allocPrint(allocator, "{s}/discover/movie?api_key={s}", .{ baseUrl, apiKey });
    const discoverResponse = try fetchJson(DiscoverResponse, url);

    for (discoverResponse.results) |movie| {
        createEntry(movie);
    }
}

pub fn main() anyerror!void {
    defer arena.deinit();

    try capy.backend.init();

    _ = try std.Thread.spawn(.{}, fetchDiscover, .{});

    var window = try capy.Window.init();

    var c = try capy.Column(.{}, .{});
    container = &c;
    try window.set(capy.Expanded(capy.Scrollable(container)));

    window.resize(800, 600);
    window.show();
    capy.runEventLoop();
}

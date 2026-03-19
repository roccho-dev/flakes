const std = @import("std");

pub const Browser = @import("browser/launcher.zig").Browser;
pub const BrowserVersion = @import("browser/launcher.zig").BrowserVersion;
pub const TargetInfo = @import("browser/launcher.zig").TargetInfo;
pub const buildChromeArgs = @import("browser/launcher.zig").buildChromeArgs;
pub const validateLaunchOptions = @import("browser/launcher.zig").validateLaunchOptions;
pub const findChrome = @import("browser/launcher.zig").findChrome;
pub const LaunchOptions = @import("browser/options.zig").LaunchOptions;
pub const Headless = @import("browser/options.zig").Headless;

pub const Connection = @import("core/connection.zig").Connection;
pub const Session = @import("core/session.zig").Session;
pub const protocol = @import("core/protocol.zig");
pub const Event = @import("core/protocol.zig").Event;
pub const Response = @import("core/protocol.zig").Response;
pub const ErrorResponse = @import("core/protocol.zig").ErrorResponse;
pub const Message = @import("core/protocol.zig").Message;

pub const Page = @import("domains/page.zig").Page;
pub const Runtime = @import("domains/runtime.zig").Runtime;
pub const CallArgument = @import("domains/runtime.zig").CallArgument;
pub const DOM = @import("domains/dom.zig").DOM;
pub const Input = @import("domains/input.zig").Input;
pub const Target = @import("domains/target.zig").Target;

pub const WebSocket = @import("transport/websocket.zig").WebSocket;

pub const json = @import("util/json.zig");
pub const base64 = @import("util/base64.zig");

pub const discovery = @import("discovery.zig");
pub const HttpResponse = discovery.HttpResponse;
pub const BrowserEndpoint = discovery.BrowserEndpoint;
pub const getChromeWsUrl = discovery.getChromeWsUrl;
pub const getChromeWsUrlAtHost = discovery.getChromeWsUrlAtHost;
pub const parseBrowserEndpoint = discovery.parseBrowserEndpoint;
pub const waitForChromeWsUrl = discovery.waitForChromeWsUrl;
pub const waitForChromeWsUrlAtHost = discovery.waitForChromeWsUrlAtHost;

pub const version = "0.2.0";
pub const protocol_version = "1.3";

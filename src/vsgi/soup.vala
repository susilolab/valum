using Soup;

/**
 * Soup implementation of VSGI.
 */
namespace VSGI.Soup {

	/**
	 * Soup Request
	 */
	class Request : VSGI.Request {

		private Message message;
		private HashTable<string, string>? _query;

		public override string method { owned get { return this.message.method ; } }

		public override URI uri { get { return this.message.uri; } }

		public override HashTable<string, string>? query { get { return this._query; } }

		public override MessageHeaders headers {
			get {
				return this.message.request_headers;
			}
		}

		public Request (Message msg, HashTable<string, string>? query) {
			this.message = msg;
			this._query = query;
		}

		/**
		 * Offset from which the response body is being read.
		 */
		private int64 offset = 0;

		public override ssize_t read (uint8[] buffer, Cancellable? cancellable = null) {
			var chunk = this.message.request_body.get_chunk (offset);

			/* potentially more data... */
			if (chunk == null)
				return -1;

			// copy the data into the buffer
			Memory.copy (buffer, chunk.data, chunk.length);

			offset += chunk.length;

			return (ssize_t) chunk.length;
		}

		/**
		 * This will complete the request MessageBody.
		 */
		public override bool close (Cancellable? cancellable = null) {
			this.message.request_body.complete ();
			return true;
		}
	}

	/**
	 * Soup Response
	 */
	class Response : VSGI.Response {

		private Message message;

		public override uint status {
			get { return this.message.status_code; }
			set { this.message.set_status (value); }
		}

		public override MessageHeaders headers {
			get { return this.message.response_headers; }
		}

		public Response (Request req, Message msg) {
			base (req);
			this.message = msg;
		}

		public override ssize_t write (uint8[] buffer, Cancellable? cancellable = null) {
			this.message.response_body.append_take (buffer);
			return buffer.length;
		}

		/**
		 * This will complete the response MessageBody.
		 *
		 * Once called, you will not be able to alter the stream.
		 */
		public override bool close (Cancellable? cancellable = null) {
			this.message.response_body.complete ();
			return true;
		}
	}

	/**
	 * Implementation of VSGI.Server based on Soup.Server.
	 *
	 * @since 0.1
	 */
	public class Server : VSGI.Server {

		private global::Soup.Server server;

		public Server (VSGI.Application application) {
			Object (application: application, flags: ApplicationFlags.HANDLES_COMMAND_LINE);

			this.server = new global::Soup.Server (global::Soup.SERVER_SERVER_HEADER, "Valum");

			this.server.add_handler (null, (server, msg, path, query, client) => {
				this.hold ();

				var req = new Request (msg, query);
				var res = new Response (req, msg);

				application.handle (req, res);

				message ("%u %s %s".printf (res.status, req.method, req.uri.get_path ()));

				this.release ();
			});

			this.add_main_option ("port", 'p', 0, OptionArg.INT, "port used to serve the HTTP server", "defaults to 3003");
		}

		public override int command_line (ApplicationCommandLine command_line) {
			var options = command_line.get_options_dict ();
			var port    = options.contains ("port") ? options.lookup_value ("port", VariantType.INT32).get_int32 () : 3003;

			this.server.listen_all (port, 0);

			foreach (var uri in this.server.get_uris ()) {
				message ("listening on %s://%s:%u", uri.scheme, uri.host, uri.port);
			}

			this.hold ();

			return 0;
		}
	}
}

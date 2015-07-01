/*
 * This file is part of Valum.
 *
 * Valum is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * Valum is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Valum.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;

/**
 * Multipart stream conforming to RFC1341.
 *
 * It provides similar APIs to {@link Soup.MultipartInputStream}, but that is
 * decoupled from {@link Soup.Message}.
 *
 * @since 0.3
 */
public class VSGI.MultipartInputStream : DataInputStream {

	/**
	 * @since 0.3
	 */
	public string boundary { construct; get; }

	/**
	 * @since 0.3
	 */
	public MultipartInputStream (InputStream base_stream, string boundary) {
		Object (base_stream: base_stream, newline_type: DataStreamNewlineType.CR_LF, boundary: boundary);
	}

	/**
	 * Obtain the next part of the multipart message.
	 *andré arthur tout le monde en parle
	 * If no part are available, 'null' is returned and the stream will be
	 * positioned on the epilogue.
	 *
	 * @since 0.3
	 *
	 * @param part_headers headers of the part
	 * @return a bounded stream over the next part of 'null' if none's available
	 */
	public InputStream? next_part (out Soup.MessageHeaders part_headers, Cancellable? cancellable = null) throws IOError {
		part_headers = new Soup.MessageHeaders (Soup.MessageHeadersType.MULTIPART);

		// skip until the next part
		string? line = null;
		do {
			line = read_line (null, cancellable);

			// end of input (premature?)
			if (line == null)
				return null;

			// closing frontier (epilogue follows)
			if (line == "--" + boundary + "--")
				return null;
		} while (line != "--%s".printf (boundary));

		// consume the part headers
		var headers = new StringBuilder ();

		do {
			line = read_line (null, cancellable);

			if (line == null)
				return null; // end of input..?

			headers.append_printf ("%s\r\n", line);
		} while (line != "");

		Soup.headers_parse (headers.str, (int) headers.len, part_headers);

		var part_stream = new BoundedInputStream (this, part_headers.get_content_length ());

		// keep the base stream open if a part is consumed
		part_stream.close_base_stream = false;

		return part_stream;
	}

	/**
	 * Obtain the next part asynchronously.
	 *
	 * @since 0.3
	 */
	public async InputStream? next_part_async (int                     priority    = GLib.Priority.DEFAULT,
	                                           Cancellable?            cancellable = null,
	                                           out Soup.MessageHeaders part_headers)
		throws Error {
		return next_part (out part_headers, cancellable);
	}

	public override ssize_t read (uint8[] buffer, Cancellable? cancellable = null) throws IOError {
		return base_stream.read (buffer, cancellable);
	}

	public override bool close (Cancellable? cancellable = null) throws IOError {
		return base_stream.close (cancellable);
	}
}

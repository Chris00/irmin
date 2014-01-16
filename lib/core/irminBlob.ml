
(*
 * Copyright (c) 2013 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

module L = Log.Make(struct let section = "VALUE" end)

exception Conflict
exception Invalid of string

module type S = sig
  include IrminBase.S
  type key
  val key: t -> key
  val of_bytes: string -> t option
  val of_bytes_exn: string -> t
  val merge: old:t -> t -> t -> t
end

module Simple  = struct

  type key = IrminKey.SHA1.t

  let key b =
    IrminKey.SHA1.of_bytes b

  include IrminBase.String

  let pretty t =
    Printf.sprintf "%S" t

  let module_name = "Blob"

  let of_bytes s = Some s

  let of_bytes_exn s = s

  let merge ~old t1 t2 =
    match compare t1 t2 with
    | 0 -> t1
    | _ ->
      match compare old t1 with
      | 0 -> t2
      | _ ->
        match compare old t2 with
        | 0 -> t1
        | _ -> raise Conflict

  (* |-----|---------| *)
  (* | 'S' | PAYLOAD | *)
  (* |-----|---------| *)

  let sizeof t =
    1 + sizeof t

  let header = "B"

  let set buf t =
    Mstruct.set_string buf header;
    set buf t

  let get buf =
    let h = Mstruct.get_string buf 1 in
    if header = h then get buf
    else None

end

module type STORE = sig
  include IrminStore.AO
  module Key: IrminKey.S with type t = key
  module Value: S with type key = key and type t = value
end

module Make
    (K: IrminKey.S)
    (B: S with type key = K.t)
    (Blob: IrminStore.AO with type key = K.t and type value = B.t)
= struct
  include Blob
  module Key  = K
  module Value = B
end

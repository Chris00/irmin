(*
 * Copyright (c) 2013-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
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

open Lwt
open Merge.OP
open Misc.OP

type origin = Origin.t

module Log = Log.Make(struct let section = "SNAPSHOT" end)

module PathSet = Misc.Set(Path)

module type STORE = sig
  include Sig.RO with type key = Path.t
  type db
  val create: db -> t Lwt.t
  val revert: db -> t -> unit Lwt.t
  val merge: db -> ?origin:Origin.t -> t -> unit Merge.result Lwt.t
  val merge_exn: db -> ?origin:Origin.t -> t -> unit Lwt.t
  val watch: db -> key -> (key * t) Lwt_stream.t
  type state
  val of_state: db -> state -> t
  val to_state: t -> state
  include Tc.I0 with type t := state
end

module Make (B: Block.STORE) (T: Tag.STORE with type value = B.key) = struct

  module N = B.Node
  module C = B.Commit
  module K = B.Key
  module S = Branch.Make(B)(T)

  type db = S.t

  type t = (S.t * S.Block.key)
  type key = S.key
  type value = S.value

  let create t =
    S.head t >>= function
    | None   -> fail Not_found
    | Some k -> return (t, k)

  let root_node (t, c) =
    C.read (S.commit_t t) c >>= function
    | None   -> return Node.empty
    | Some c ->
      match C.node (S.commit_t t) c with
      | None   -> return Node.empty
      | Some n -> n

  let map (t, c) path ~f =
    root_node (t, c) >>= fun node ->
    f (S.node_t t) node path

  let read (t:t) path =
    map t path ~f:N.find

  let read_exn t path =
    read t path >>= function
    | None   -> fail Not_found
    | Some x -> return x

  let mem t path =
    map t path ~f:N.valid

  (* XXX: code duplication with Branch.list *)
  let list (t, c) paths =
    Log.debugf "list";
    let one path =
      root_node (t, c) >>= fun n ->
      N.sub (S.node_t t) n path >>= function
      | None      -> return_nil
      | Some node ->
        let c = N.succ (S.node_t t) node in
        let c = Misc.StringMap.keys c in
        let paths = List.map (fun c -> path @ [c]) c in
        return paths in
    Lwt_list.fold_left_s (fun set p ->
        one p >>= fun paths ->
        let paths = PathSet.of_list paths in
        return (PathSet.union set paths)
      ) PathSet.empty paths
    >>= fun paths ->
    return (PathSet.to_list paths)

  let dump (t, c) =
    failwith "TODO"

  let revert t (_, c) =
    Log.debugf "revert %a" force (show (module K) c);
    match S.tag t with
    | None     -> S.set_head t c; return_unit
    | Some tag -> T.update (S.tag_t t) tag c

  let merge t ?origin (_, c) =
    Log.debugf "merge %a" force (show (module K) c);
    let origin = match origin with
      | None   -> Origin.create "Merge snapshot %s" (K.pretty c)
      | Some o -> o in
    S.merge_commit t ~origin c

  let merge_exn t ?origin c =
    merge t ?origin c >>=
    Merge.exn

  let watch db path =
    let stream = S.watch_node db path in
    Lwt_stream.map (fun (path, c) -> path, (db ,c)) stream

  type state = S.Block.key

  let of_state t s = (t, s)

  let to_state (_, s) = s

  include (S.Block.Key: Tc.I0 with type t := state)

end

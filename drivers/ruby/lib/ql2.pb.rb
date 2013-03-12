### Generated by rprotoc. DO NOT EDIT!
### <proto file: ../../src/rdb_protocol/ql2.proto>
# ////////////////////////////////////////////////////////////////////////////////
# //                            THE HIGH-LEVEL VIEW                             //
# ////////////////////////////////////////////////////////////////////////////////
# 
# // Process: First send the magic number for the version of the protobuf you're
# // targetting (in the [Version] enum).  This should **NOT** be sent as a
# // protobuf; just send the little-endian 32-bit integer over the wire raw.
# // Next, send [Query] protobufs and wait for [Response] protobufs with the same
# // token.  You can see an example exchange below in **EXAMPLE**.
# 
# // A query consists of a [Term] to evaluate and a unique-per-connection
# // [token].
# 
# // Tokens are used for two things:
# // * Keeping track of which responses correspond to which queries.
# // * Batched queries.  Some queries return lots of results, so we send back
# //   batches of <1000, and you need to send a [CONTINUE] query with the same
# //   token to get more results from the original query.
# ////////////////////////////////////////////////////////////////////////////////
# 
# // This enum contains the magic numbers for your version.  See **THE HIGH-LEVEL
# // VIEW** for what to do with it.
# message VersionDummy { // We need to wrap it like this for some
#                        // non-conforming protobuf libraries
#     enum Version {
#         V0_1 = 0x3f61ba36;
#     };
# };
# 
# // You send one of:
# // * A [START] query with a [Term] to evaluate and a unique-per-connection token.
# // * A [CONTINUE] query with the same token as a [START] query that returned
# //   [SUCCESS_PARTIAL] in its [Response].
# // * A [STOP] query with the same token as a [START] query that you want to stop.
# message Query {
#     enum QueryType {
#         START    = 1; // Start a new query.
#         CONTINUE = 2; // Continue a query that returned [SUCCESS_PARTIAL]
#                       // (see [Response]).
#         STOP     = 3; // Stop a query partway through executing.
#     };
#     required QueryType type = 1;
#     // A [Term] is how we represent the operations we want a query to perform.
#     optional Term query = 2; // only present when [type] = [START]
#     required int64 token = 3;
#     optional bool noreply = 4 [default = false]; // CURRENTLY IGNORED, NO SERVER SUPPORT
# 
#     message AssocPair {
#         required string key = 1;
#         required Term val = 2;
#     };
#     repeated AssocPair global_optargs = 6;
# };
# 
# // A backtrace frame (see `backtrace` in Response below)
# message Frame {
#     enum FrameType {
#         POS = 1; // Error occured in a positional argument.
#         OPT = 2; // Error occured in an optional argument.
#     };
#     required FrameType type = 1;
#     optional int64 pos = 2; // The index of the positional argument.
#     optional string opt = 3; // The name of the optional argument.
# };
# message Backtrace {
#     repeated Frame frames = 1;
# }
# 
# // You get back a response with the same [token] as your query.
# message Response {
#     enum ResponseType {
#         // These response types indicate success.
#         SUCCESS_ATOM     = 1; // Query returned a single RQL datatype.
#         SUCCESS_SEQUENCE = 2; // Query returned a sequence of RQL datatypes.
#         SUCCESS_PARTIAL  = 3; // Query returned a partial sequence of RQL
#                               // datatypes.  If you send a [CONTINUE] query with
#                               // the same token as this response, you will get
#                               // more of the sequence.  Keep sending [CONTINUE]
#                               // queries until you get back [SUCCESS_SEQUENCE].
# 
#         // These response types indicate failure.
#         CLIENT_ERROR  = 16; // Means the client is buggy.  An example is if the
#                             // client sends a malformed protobuf, or tries to
#                             // send [CONTINUE] for an unknown token.
#         COMPILE_ERROR = 17; // Means the query failed during parsing or type
#                             // checking.  For example, if you pass too many
#                             // arguments to a function.
#         RUNTIME_ERROR = 18; // Means the query failed at runtime.  An example is
#                             // if you add together two values from a table, but
#                             // they turn out at runtime to be booleans rather
#                             // than numbers.
#     };
#     required ResponseType type = 1;
#     required int64 token = 2; // Indicates what [Query] this response corresponds to.
# 
#     // [response] contains 1 RQL datum if [type] is [SUCCESS_ATOM], or many RQL
#     // data if [type] is [SUCCESS_SEQUENCE] or [SUCCESS_PARTIAL].  It contains 1
#     // error message (of type [R_STR]) in all other cases.
#     repeated Datum response = 3;
# 
#     // If [type] is [CLIENT_ERROR], [TYPE_ERROR], or [RUNTIME_ERROR], then a
#     // backtrace will be provided.  The backtrace says where in the query the
#     // error occured.  Ideally this information will be presented to the user as
#     // a pretty-printed version of their query with the erroneous section
#     // underlined.  A backtrace is a series of 0 or more [Frame]s, each of which
#     // specifies either the index of a positional argument or the name of an
#     // optional argument.  (Those words will make more sense if you look at the
#     // [Term] message below.)
# 
#     optional Backtrace backtrace = 4; // Contains n [Frame]s when you get back an error.
# };
# 
# // A [Datum] is a chunk of data that can be serialized to disk or returned to
# // the user in a Response.  Currently we only support JSON types, but we may
# // support other types in the future (e.g., a date type or an integer type).
# message Datum {
#     enum DatumType {
#         R_NULL   = 1;
#         R_BOOL   = 2;
#         R_NUM    = 3; // a double
#         R_STR    = 4;
#         R_ARRAY  = 5;
#         R_OBJECT = 6;
#     };
#     required DatumType type = 1;
#     optional bool r_bool = 2;
#     optional double r_num = 3;
#     optional string r_str = 4;
# 
#     repeated Datum r_array = 5;
#     message AssocPair {
#         required string key = 1;
#         required Datum val = 2;
#     };
#     repeated AssocPair r_object = 6;
# 
#     extensions 10000 to 20000;
# };
# 
# // A [Term] is either a piece of data (see **Datum** above), or an operator and
# // its operands.  If you have a [Datum], it's stored in the member [datum].  If
# // you have an operator, its positional arguments are stored in [args] and its
# // optional arguments are stored in [optargs].
# //
# // A note about type signatures:
# // We use the following notation to denote types:
# //   arg1_type, arg2_type, argrest_type... -> result_type
# // So, for example, if we have a function `avg` that takes any number of
# // arguments and averages them, we might write:
# //   NUMBER... -> NUMBER
# // Or if we had a function that took one number modulo another:
# //   NUMBER, NUMBER -> NUMBER
# // Or a function that takes a table and a primary key of any Datum type, then
# // retrieves the entry with that primary key:
# //   Table, DATUM -> OBJECT
# // Some arguments must be provided as literal values (and not the results of sub
# // terms).  These are marked with a `!`.
# // Optional arguments are specified within curly braces as argname `:` value
# // type (e.x `{use_outdated:BOOL}`)
# // The RQL type hierarchy is as follows:
# //   Top
# //     DATUM
# //       NULL
# //       BOOL
# //       NUMBER
# //       STRING
# //       OBJECT
# //         SingleSelection
# //       ARRAY
# //     Sequence
# //       ARRAY
# //       Stream
# //         StreamSelection
# //           Table
# //     Database
# //     Function
# //   Error
# message Term {
#     enum TermType {
#         // A RQL datum, stored in `datum` below.
#         DATUM = 1;
# 
#         MAKE_ARRAY = 2; // DATUM... -> ARRAY
#         // Evaluate the terms in [optargs] and make an object
#         MAKE_OBJ   = 3; // {...} -> OBJECT
# 
#         // * Compound types
#         // Takes an integer representing a variable and returns the value stored
#         // in that variable.  It's the responsibility of the client to translate
#         // from their local representation of a variable to a unique integer for
#         // that variable.  (We do it this way instead of letting clients provide
#         // variable names as strings to discourage variable-capturing client
#         // libraries, and because it's more efficient on the wire.)
#         VAR          = 10; // !NUMBER -> DATUM
#         // Takes some javascript code and executes it.
#         JAVASCRIPT   = 11; // STRING -> DATUM | STRING -> Function(*)
#         // Takes a string and throws an error with that message.
#         ERROR        = 12; // STRING -> Error
#         // Takes nothing and returns a reference to the implicit variable.
#         IMPLICIT_VAR = 13; // -> DATUM
# 
#         // * Data Operators
#         // Returns a reference to a database.
#         DB    = 14; // STRING -> Database
#         // Returns a reference to a table.
#         TABLE = 15; // Database, STRING, {use_outdated:BOOL} -> Table | STRING, {use_outdated:BOOL} -> Table
#         // Gets a single element from a table by its primary key.
#         GET   = 16; // Table, STRING -> SingleSelection | Table, NUMBER -> SingleSelection |
#                     // Table, STRING -> NULL            | Table, NUMBER -> NULL
# 
#         // Simple DATUM Ops
#         EQ  = 17; // DATUM... -> BOOL
#         NE  = 18; // DATUM... -> BOOL
#         LT  = 19; // DATUM... -> BOOL
#         LE  = 20; // DATUM... -> BOOL
#         GT  = 21; // DATUM... -> BOOL
#         GE  = 22; // DATUM... -> BOOL
#         NOT = 23; // BOOL -> BOOL
#         // ADD can either add two numbers or concatenate two arrays.
#         ADD = 24; // NUMBER... -> NUMBER | STRING... -> STRING
#         SUB = 25; // NUMBER... -> NUMBER
#         MUL = 26; // NUMBER... -> NUMBER
#         DIV = 27; // NUMBER... -> NUMBER
#         MOD = 28; // NUMBER, NUMBER -> NUMBER
# 
#         // DATUM Array Ops
#         // Append a single element to the end of an array (like `snoc`).
#         APPEND = 29; // ARRAY, DATUM -> ARRAY
#         SLICE  = 30; // Sequence, NUMBER, NUMBER -> Sequence
#         SKIP  = 70; // Sequence, NUMBER -> Sequence
#         LIMIT = 71; // Sequence, NUMBER -> Sequence
# 
#         // Stream/Object Ops
#         // Get a particular attribute out of an object, or map that over a
#         // sequence.
#         GETATTR  = 31; // OBJECT, STRING -> DATUM
#         // Check whether an object contains all of a set of attributes, or map
#         // that over a sequence.
#         CONTAINS = 32; // OBJECT, STRING... -> BOOL
#         // Get a subset of an object by selecting some attributes to preserve,
#         // or map that over a sequence.  (Both pick and pluck, polymorphic.)
#         PLUCK    = 33; // Sequence, STRING... -> Sequence | OBJECT, STRING... -> OBJECT
#         // Get a subset of an object by selecting some attributes to discard, or
#         // map that over a sequence.  (Both unpick and without, polymorphic.)
#         WITHOUT  = 34; // Sequence, STRING... -> Sequence | OBJECT, STRING... -> OBJECT
#         // Merge objects (right-preferential)
#         MERGE    = 35; // OBJECT... -> OBJECT | Sequence -> Sequence
# 
#         // Sequence Ops
#         // Get all elements of a sequence between two values.
#         BETWEEN   = 36; // StreamSelection, {left_bound:DATUM, right_bound:DATUM} -> StreamSelection
#         REDUCE    = 37; // Sequence, Function(2), {base:DATUM} -> DATUM
#         MAP       = 38; // Sequence, Function(1) -> Sequence
#         FILTER    = 39; // Sequence, Function(1) -> Sequence | Sequence, OBJECT -> Sequence
#         // Map a function over a sequence and then concatenate the results together.
#         CONCATMAP = 40; // Sequence, Function(1) -> Sequence
#         // Order a sequence based on one or more attributes.
#         ORDERBY   = 41; // Sequence, !STRING... -> Sequence
#         // Get all distinct elements of a sequence (like `uniq`).
#         DISTINCT  = 42; // Sequence -> Sequence
#         // Count the number of elements in a sequence.
#         COUNT     = 43; // Sequence -> NUMBER
#         // Take the union of multiple sequences (preserves duplicate elements! (use distinct)).
#         UNION     = 44; // Sequence... -> Sequence
#         // Get the Nth element of a sequence.
#         NTH       = 45; // Sequence, NUMBER -> DATUM
#         // Takes a sequence, and three functions:
#         // - A function to group the sequence by.
#         // - A function to map over the groups.
#         // - A reduction to apply to each of the groups.
#         GROUPED_MAP_REDUCE = 46; // Sequence, Function(1), Function(1), Function(2), {base:DATUM} -> Sequence
#         // Groups a sequence by one or more attributes, and then applies a reduction.
#         GROUPBY            = 47; // Sequence, ARRAY, !OBJECT -> Sequence
#         INNER_JOIN         = 48; // Sequence, Sequence, Function(2) -> Sequence
#         OUTER_JOIN         = 49; // Sequence, Sequence, Function(2) -> Sequence
#         // An inner-join that does an equality comparison on two attributes.
#         EQ_JOIN            = 50; // Sequence, !STRING, Sequence -> Sequence
#         ZIP                = 72; // Sequence -> Sequence
# 
# 
#         // * Type Ops
#         // Coerces a datum to a named type (e.g. "bool").
#         // If you previously used `stream_to_array`, you should use this instead
#         // with the type "array".
#         COERCE_TO = 51; // Top, STRING -> Top
#         // Returns the named type of a datum (e.g. TYPEOF(true) = "BOOL")
#         TYPEOF = 52; // Top -> STRING
# 
#         // * Write Ops (the OBJECTs contain data about number of errors etc.)
#         // Updates all the rows in a selection.  Calls its Function with the row
#         // to be updated, and then merges the result of that call.
#         UPDATE   = 53; // StreamSelection, Function(1), {non_atomic:BOOL} -> OBJECT |
#                        // SingleSelection, Function(1), {non_atomic:BOOL} -> OBJECT |
#                        // StreamSelection, OBJECT,      {non_atomic:BOOL} -> OBJECT |
#                        // SingleSelection, OBJECT,      {non_atomic:BOOL} -> OBJECT
#         // Deletes all the rows in a selection.
#         DELETE   = 54; // StreamSelection -> OBJECT | SingleSelection -> OBJECT
#         // Replaces all the rows in a selection.  Calls its Function with the row
#         // to be replaced, and then discards it and stores the result of that
#         // call.
#         REPLACE  = 55; // StreamSelection, Function(1), {non_atomic:BOOL} -> OBJECT | SingleSelection, Function(1), {non_atomic:BOOL} -> OBJECT
#         // Inserts into a table.  If `upsert` is true, overwrites entries with
#         // the same primary key (otherwise errors).
#         INSERT   = 56; // Table, OBJECT, {upsert:BOOL} -> OBJECT | Table, Sequence, {upsert:BOOL} -> OBJECT
# 
#         // * Administrative OPs
#         // Creates a database with a particular name.
#         DB_CREATE    = 57; // STRING -> OBJECT
#         // Drops a database with a particular name.
#         DB_DROP      = 58; // STRING -> OBJECT
#         // Lists all the databases by name.  (Takes no arguments)
#         DB_LIST      = 59; // -> ARRAY
#         // Creates a table with a particular name in a particular database.
#         TABLE_CREATE = 60; // Database, STRING, {datacenter:STRING, primary_key:STRING, cache_size:NUMBER} -> OBJECT
#         // Drops a table with a particular name from a particular database.
#         TABLE_DROP   = 61; // Database, STRING -> OBJECT
#         // Lists all the tables in a particular database.
#         TABLE_LIST   = 62; // Database -> ARRAY
# 
#         // * Control Operators
#         // Calls a function on data
#         FUNCALL  = 64; // Function(*), DATUM... -> DATUM
#         // Executes its first argument, and returns its second argument if it
#         // got [true] or its third argument if it got [false] (like an `if`
#         // statement).
#         BRANCH  = 65; // BOOL, Top, Top -> Top
#         // Returns true if any of its arguments returns true (short-circuits).
#         // (Like `or` in most languages.)
#         ANY     = 66; // BOOL... -> BOOL
#         // Returns true if all of its arguments return true (short-circuits).
#         // (Like `and` in most languages.)
#         ALL     = 67; // BOOL... -> BOOL
#         // Calls its Function with each entry in the sequence
#         // and executes the array of terms that Function returns.
#         FOREACH = 68; // Sequence, Function(1) -> OBJECT
# 
# ////////////////////////////////////////////////////////////////////////////////
# ////////// Special Terms
# ////////////////////////////////////////////////////////////////////////////////
# 
#         // An anonymous function.  Takes an array of numbers representing
#         // variables (see [VAR] above), and a [Term] to execute with those in
#         // scope.  Returns a function that may be passed an array of arguments,
#         // then executes the Term with those bound to the variable names.  The
#         // user will never construct this directly.  We use it internally for
#         // things like `map` which take a function.  The "arity" of a [Function] is
#         // the number of arguments it takes.
#         // For example, here's what `_X_.map{|x| x+2}` turns into:
#         // Term {
#         //   type = MAP;
#         //   args = [_X_,
#         //           Term {
#         //             type = Function;
#         //             args = [Term {
#         //                       type = DATUM;
#         //                       datum = Datum {
#         //                         type = R_ARRAY;
#         //                         r_array = [Datum { type = R_NUM; r_num = 1; }];
#         //                       };
#         //                     },
#         //                     Term {
#         //                       type = ADD;
#         //                       args = [Term {
#         //                                 type = VAR;
#         //                                 args = [Term {
#         //                                           type = DATUM;
#         //                                           datum = Datum { type = R_NUM; r_num = 1};
#         //                                         }];
#         //                               },
#         //                               Term {
#         //                                 type = DATUM;
#         //                                 datum = Datum { type = R_NUM; r_num = 2; };
#         //                               }];
#         //                     }];
#         //           }];
#         FUNC = 69; // ARRAY, Top -> ARRAY -> Top
# 
#         ASC = 73;
#         DESC = 74;
#     };
#     required TermType type = 1;
# 
#     // This is only used when type is DATUM.
#     optional Datum datum = 2;
# 
#     repeated Term args = 3; // Holds the positional arguments of the query.
#     message AssocPair {
#         required string key = 1;
#         required Term val = 2;
#     };
#     repeated AssocPair optargs = 4; // Holds the optional arguments of the query.
#     // (Note that the order of the optional arguments doesn't matter; think of a
#     // Hash.)
# 
#     extensions 10000 to 20000;
# };
# 
# ////////////////////////////////////////////////////////////////////////////////
# //                                  EXAMPLE                                   //
# ////////////////////////////////////////////////////////////////////////////////
# //   ```ruby
# //   r.table('tbl', {:use_outdated => true}).insert([{:id => 0}, {:id => 1}])
# //   ```
# // Would turn into:
# //   Term {
# //     type = INSERT;
# //     args = [Term {
# //               type = TABLE;
# //               args = [Term {
# //                         type = R_DATUM;
# //                         r_datum = Datum { type = R_STR; r_str = "tbl"; };
# //                       }];
# //               optargs = [["use_outdated",
# //                           Term {
# //                             type = R_DATUM;
# //                             r_datum = Datum { type = R_BOOL; r_bool = true; };
# //                           }]];
# //             },
# //             Term {
# //               type = R_ARRAY;
# //               args = [Term {
# //                         type = R_DATUM;
# //                         r_datum = Datum { type = R_OBJECT; r_object = [["id", 0]]; };
# //                       },
# //                       Term {
# //                         type = R_DATUM;
# //                         r_datum = Datum { type = R_OBJECT; r_object = [["id", 1]]; };
# //                       }];
# //             }]
# //   }
# // And the server would reply:
# //   Response {
# //     type = SUCCESS_ATOM;
# //     token = 1;
# //     response = [Datum { type = R_OBJECT; r_object = [["inserted", 2]]; }];
# //   }
# // Or, if there were an error:
# //   Response {
# //     type = RUNTIME_ERROR;
# //     token = 1;
# //     response = [Datum { type = R_STR; r_str = "The table `tbl` doesn't exist!"; }];
# //     backtrace = [Frame { type = POS; pos = 0; }, Frame { type = POS; pos = 0; }];
# //   }

require 'protobuf/message/message'
require 'protobuf/message/enum'
require 'protobuf/message/service'
require 'protobuf/message/extend'

class VersionDummy < ::Protobuf::Message
  defined_in __FILE__
  class Version < ::Protobuf::Enum
    defined_in __FILE__
    V0_1 = value(:V0_1, 1063369270)
  end
end
class Query < ::Protobuf::Message
  defined_in __FILE__
  class QueryType < ::Protobuf::Enum
    defined_in __FILE__
    START = value(:START, 1)
    CONTINUE = value(:CONTINUE, 2)
    STOP = value(:STOP, 3)
  end
  required :QueryType, :type, 1
  optional :Term, :query, 2
  required :int64, :token, 3
  optional :bool, :noreply, 4, :default => false
  class AssocPair < ::Protobuf::Message
    defined_in __FILE__
    required :string, :key, 1
    required :Term, :val, 2
  end
  repeated :AssocPair, :global_optargs, 6
end
class Frame < ::Protobuf::Message
  defined_in __FILE__
  class FrameType < ::Protobuf::Enum
    defined_in __FILE__
    POS = value(:POS, 1)
    OPT = value(:OPT, 2)
  end
  required :FrameType, :type, 1
  optional :int64, :pos, 2
  optional :string, :opt, 3
end
class Backtrace < ::Protobuf::Message
  defined_in __FILE__
  repeated :Frame, :frames, 1
end
class Response < ::Protobuf::Message
  defined_in __FILE__
  class ResponseType < ::Protobuf::Enum
    defined_in __FILE__
    SUCCESS_ATOM = value(:SUCCESS_ATOM, 1)
    SUCCESS_SEQUENCE = value(:SUCCESS_SEQUENCE, 2)
    SUCCESS_PARTIAL = value(:SUCCESS_PARTIAL, 3)
    CLIENT_ERROR = value(:CLIENT_ERROR, 16)
    COMPILE_ERROR = value(:COMPILE_ERROR, 17)
    RUNTIME_ERROR = value(:RUNTIME_ERROR, 18)
  end
  required :ResponseType, :type, 1
  required :int64, :token, 2
  repeated :Datum, :response, 3
  optional :Backtrace, :backtrace, 4
end
class Datum < ::Protobuf::Message
  defined_in __FILE__
  class DatumType < ::Protobuf::Enum
    defined_in __FILE__
    R_NULL = value(:R_NULL, 1)
    R_BOOL = value(:R_BOOL, 2)
    R_NUM = value(:R_NUM, 3)
    R_STR = value(:R_STR, 4)
    R_ARRAY = value(:R_ARRAY, 5)
    R_OBJECT = value(:R_OBJECT, 6)
  end
  required :DatumType, :type, 1
  optional :bool, :r_bool, 2
  optional :double, :r_num, 3
  optional :string, :r_str, 4
  repeated :Datum, :r_array, 5
  class AssocPair < ::Protobuf::Message
    defined_in __FILE__
    required :string, :key, 1
    required :Datum, :val, 2
  end
  repeated :AssocPair, :r_object, 6
  extensions 10000..20000
end
class Term < ::Protobuf::Message
  defined_in __FILE__
  class TermType < ::Protobuf::Enum
    defined_in __FILE__
    DATUM = value(:DATUM, 1)
    MAKE_ARRAY = value(:MAKE_ARRAY, 2)
    MAKE_OBJ = value(:MAKE_OBJ, 3)
    VAR = value(:VAR, 10)
    JAVASCRIPT = value(:JAVASCRIPT, 11)
    ERROR = value(:ERROR, 12)
    IMPLICIT_VAR = value(:IMPLICIT_VAR, 13)
    DB = value(:DB, 14)
    TABLE = value(:TABLE, 15)
    GET = value(:GET, 16)
    EQ = value(:EQ, 17)
    NE = value(:NE, 18)
    LT = value(:LT, 19)
    LE = value(:LE, 20)
    GT = value(:GT, 21)
    GE = value(:GE, 22)
    NOT = value(:NOT, 23)
    ADD = value(:ADD, 24)
    SUB = value(:SUB, 25)
    MUL = value(:MUL, 26)
    DIV = value(:DIV, 27)
    MOD = value(:MOD, 28)
    APPEND = value(:APPEND, 29)
    SLICE = value(:SLICE, 30)
    SKIP = value(:SKIP, 70)
    LIMIT = value(:LIMIT, 71)
    GETATTR = value(:GETATTR, 31)
    CONTAINS = value(:CONTAINS, 32)
    PLUCK = value(:PLUCK, 33)
    WITHOUT = value(:WITHOUT, 34)
    MERGE = value(:MERGE, 35)
    BETWEEN = value(:BETWEEN, 36)
    REDUCE = value(:REDUCE, 37)
    MAP = value(:MAP, 38)
    FILTER = value(:FILTER, 39)
    CONCATMAP = value(:CONCATMAP, 40)
    ORDERBY = value(:ORDERBY, 41)
    DISTINCT = value(:DISTINCT, 42)
    COUNT = value(:COUNT, 43)
    UNION = value(:UNION, 44)
    NTH = value(:NTH, 45)
    GROUPED_MAP_REDUCE = value(:GROUPED_MAP_REDUCE, 46)
    GROUPBY = value(:GROUPBY, 47)
    INNER_JOIN = value(:INNER_JOIN, 48)
    OUTER_JOIN = value(:OUTER_JOIN, 49)
    EQ_JOIN = value(:EQ_JOIN, 50)
    ZIP = value(:ZIP, 72)
    COERCE_TO = value(:COERCE_TO, 51)
    TYPEOF = value(:TYPEOF, 52)
    UPDATE = value(:UPDATE, 53)
    DELETE = value(:DELETE, 54)
    REPLACE = value(:REPLACE, 55)
    INSERT = value(:INSERT, 56)
    DB_CREATE = value(:DB_CREATE, 57)
    DB_DROP = value(:DB_DROP, 58)
    DB_LIST = value(:DB_LIST, 59)
    TABLE_CREATE = value(:TABLE_CREATE, 60)
    TABLE_DROP = value(:TABLE_DROP, 61)
    TABLE_LIST = value(:TABLE_LIST, 62)
    FUNCALL = value(:FUNCALL, 64)
    BRANCH = value(:BRANCH, 65)
    ANY = value(:ANY, 66)
    ALL = value(:ALL, 67)
    FOREACH = value(:FOREACH, 68)
    FUNC = value(:FUNC, 69)
    ASC = value(:ASC, 73)
    DESC = value(:DESC, 74)
  end
  required :TermType, :type, 1
  optional :Datum, :datum, 2
  repeated :Term, :args, 3
  class AssocPair < ::Protobuf::Message
    defined_in __FILE__
    required :string, :key, 1
    required :Term, :val, 2
  end
  repeated :AssocPair, :optargs, 4
  extensions 10000..20000
end
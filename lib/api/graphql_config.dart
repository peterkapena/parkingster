import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

const String graphQLEndpoint = kDebugMode
    ? 'http://10.0.2.2:4000/graphql'
    : "https://api.mtm.peterkapena.com/graphql/";
 
const String accessTokenString = "accessToken";
const String refreshTokenString = "refreshToken";
const String emailString = 'email';

class GraphQLConfig {
  static Future<ValueNotifier<GraphQLClient>> initClient() async {
    final HttpLink httpLink = HttpLink(graphQLEndpoint);

    return ValueNotifier(
      GraphQLClient(
        cache: GraphQLCache(store: InMemoryStore()),
        link: httpLink,
      ),
    );
  }
}

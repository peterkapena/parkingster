import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class ClientProvider extends StatelessWidget {
  final Widget child;

  const ClientProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final client = GraphQLProvider.of(context).value;
    return GraphQLProvider(
      client: ValueNotifier(client),
      child: child,
    );
  }
}

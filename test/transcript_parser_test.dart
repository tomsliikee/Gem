import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/domain/entities/subagent_node.dart';

void main() {
  group('TranscriptParser Unit Tests', () {
    test('Parses a valid JSONL line correctly into a SubagentNode', () {
      const line = '{"timestamp": "2026-06-19T18:50:00.000Z", "agent_id": "agent-123", "parent_id": null, "state": "Thinking", "log": "Initializing task..."}';
      
      final jsonMap = jsonDecode(line) as Map<String, dynamic>;
      final node = SubagentNode.fromJson(jsonMap);

      expect(node.agentId, 'agent-123');
      expect(node.parentId, isNull);
      expect(node.state, AgentState.thinking);
      expect(node.log, 'Initializing task...');
    });

    test('Throws FormatException or handles malformed states gracefully', () {
      const malformedLine = '{"timestamp": "invalid-time", "agent_id": "agent-123", "state": "UnknownState"}';
      final jsonMap = jsonDecode(malformedLine) as Map<String, dynamic>;
      
      expect(
        () => SubagentNode.fromJson(jsonMap),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

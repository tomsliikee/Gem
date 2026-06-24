enum AgentState { thinking, runningCommand, completed, failed }

class SubagentNode {
  final DateTime timestamp;
  final String agentId;
  final String? parentId;
  final AgentState state;
  final String? log;

  SubagentNode({
    required this.timestamp,
    required this.agentId,
    this.parentId,
    required this.state,
    this.log,
  });

  factory SubagentNode.fromJson(Map<String, dynamic> json) {
    if (json['timestamp'] == null || json['agent_id'] == null || json['state'] == null) {
      throw const FormatException('Missing required fields');
    }
    
    // Validate timestamp format to prevent invalid-time crashes
    try {
      DateTime.parse(json['timestamp'] as String);
    } catch (_) {
      throw const FormatException('Invalid timestamp format');
    }

    AgentState parsedState;
    switch (json['state'] as String) {
      case 'Thinking':
        parsedState = AgentState.thinking;
        break;
      case 'Running Command':
        parsedState = AgentState.runningCommand;
        break;
      case 'Completed':
        parsedState = AgentState.completed;
        break;
      case 'Failed':
        parsedState = AgentState.failed;
        break;
      default:
        throw FormatException('Unknown agent state: ${json['state']}');
    }

    return SubagentNode(
      timestamp: DateTime.parse(json['timestamp'] as String),
      agentId: json['agent_id'] as String,
      parentId: json['parent_id'] as String?,
      state: parsedState,
      log: json['log'] as String?,
    );
  }
}

import 'package:flutter/material.dart';

import 'export_wizard.dart';
import 'gemmell.dart';
import 'models.dart';

const gemmellQuestions = <GemmellTool, String>{
  GemmellTool.discoverEncyclopediaEntries: 'Would you like to find people, places, or other things that need encyclopedia entries?',
  GemmellTool.proofreadSelection: 'Do you want spelling and grammar checked?',
  GemmellTool.suggestRewrite:
      'Would you like several alternative ways to word this passage?',
  GemmellTool.explainSelection:
      'Do you want to understand how a reader might interpret this passage?',
  GemmellTool.characterVoice:
      'Are you worried this character sounds unlike themselves?',
  GemmellTool.povLeak:
      'Could the viewpoint character know or perceive too much?',
  GemmellTool.factCheck: 'Do you need to verify a real-world claim?',
  GemmellTool.encyclopediaDraft:
      'Do you want to draft an encyclopedia entry from this passage?',
  GemmellTool.structuredFactsFromProse: 'Do you want to extract structured facts about entities from the passage?',
  GemmellTool.expandProse: 'Do you want a longer version of the passage?',
  GemmellTool.condenseProse: 'Do you want a shorter version of the passage?',
  GemmellTool.rewriteForClarity: 'Do you want the wording to be clearer?',
  GemmellTool.adjustReadingLevel:
      'Do you want to adjust the reading difficulty?',
  GemmellTool.ideaQuestions:
      'Would questions help you work out what to write next?',
  GemmellTool.sceneReview:
      'Do you want a general check of spelling, clarity and style?',
  GemmellTool.continuity:
      'Are you worried that facts in this scene contradict one another?',
  GemmellTool.knowledge:
      'Could a character be acting on information they have not learned?',
  GemmellTool.voiceDrift:
      'Are you worried about inconsistent dialogue or narration?',
  GemmellTool.foreshadowing: 'Do you want to trace hints and possible payoffs?',
  GemmellTool.unresolvedSetups:
      'Are you looking for promises or hooks that have not paid off?',
  GemmellTool.scenePurpose:
      'Do you want to understand what this scene accomplishes?',
  GemmellTool.pacing: 'Are you worried this scene moves too quickly or slowly?',
  GemmellTool.readerKnowledge:
      'Do you want to know what readers can understand or suspect so far?',
  GemmellTool.mysteryFairness: 'Do you want to check whether readers have a fair chance of solving the mystery?',
  GemmellTool.worldRules:
      'Could the scene break an established rule of your world?',
  GemmellTool.termConsistency:
      'Are names or terms being spelled or used inconsistently?',
  GemmellTool.researchDebt:
      'Do you want a list of things that need real-world research?',
  GemmellTool.sensitivityQuestions: 'Do you want questions to guide research or informed feedback on sensitive topics?',
  GemmellTool.developmentalReview:
      'Do you want feedback on stakes, motivation and scene structure?',
  GemmellTool.ideas: 'Would several possible story directions help?',
  GemmellTool.storyContinuity:
      'Do you want to check facts for contradictions across the manuscript?',
  GemmellTool.storyKnowledge:
      'Do you want to trace when characters learn important information?',
  GemmellTool.storyForeshadowing:
      'Do you want to map clues and payoffs across the story?',
  GemmellTool.storyForgottenCharacters:
      'Do you want to find important characters who disappear from the story?',
  GemmellTool.storyRelationships:
      'Do you want to check whether relationship changes feel supported?',
  GemmellTool.storyPacing:
      'Do you want to compare pacing across the whole manuscript?',
  GemmellTool.storyDevelopmental:
      'Do you want feedback on the overall structure and character arcs?',
  GemmellTool.storyCanon: 'Do you want to compare world rules and terminology with the encyclopedia?',
  GemmellTool.encyclopediaReview: 'Do you want a general review of this entry?',
  GemmellTool.encyclopediaCanonCheck:
      'Could this entry contradict another encyclopedia entry?',
  GemmellTool.encyclopediaGaps:
      'Do you want useful questions about missing information?',
  GemmellTool.encyclopediaRelationships:
      'Do you want to identify relationships between entries?',
  GemmellTool.encyclopediaAliases:
      'Do you want to find alternate names and naming inconsistencies?',
  GemmellTool.encyclopediaStructure:
      'Do you want to organize this entry more clearly?',
  GemmellTool.encyclopediaBodyToFacts:
      'Do you want to extract structured fields from the entry body?',
};

ExportDecision<GemmellTool> gemmellDecision(List<GemmellTool> tools) {
  ExportDecision<GemmellTool> leaf(GemmellTool t) => ExportDecision.result(
    '${t.label}\n\n${t.instruction}\n\n${t.example}',
    t,
  );
  ExportDecision<GemmellTool> choose(List<GemmellTool> values) {
    if (values.length == 1) return leaf(values.single);
    return ExportDecision.question(
      gemmellQuestions[values.first]!,
      leaf(values.first),
      choose(values.sublist(1)),
    );
  }

  final groups = <(String, bool Function(GemmellTool))>[
    (
      'Do you want help with encyclopedia entries or facts about your world?',
      (t) =>
          t.encyclopediaOnly ||
          {
            GemmellTool.discoverEncyclopediaEntries,
            GemmellTool.encyclopediaDraft,
            GemmellTool.structuredFactsFromProse,
          }.contains(t),
    ),
    (
      'Do you want to review the entire story, using a portable project attachment?',
      (t) => t.requiresPackage,
    ),
    (
      'Do you want suggestions that change the wording of selected prose?',
      (t) => t.proseTransformation,
    ),
    (
      'Are you checking consistency, character knowledge, or world rules?',
      (t) => {
        GemmellTool.continuity,
        GemmellTool.knowledge,
        GemmellTool.voiceDrift,
        GemmellTool.characterVoice,
        GemmellTool.povLeak,
        GemmellTool.worldRules,
        GemmellTool.termConsistency,
      }.contains(t),
    ),
    (
      'Are you looking at clues, promises, or what the reader knows?',
      (t) => {
        GemmellTool.foreshadowing,
        GemmellTool.unresolvedSetups,
        GemmellTool.readerKnowledge,
        GemmellTool.mysteryFairness,
      }.contains(t),
    ),
    (
      'Do you need help with real-world research or informed feedback?',
      (t) => {
        GemmellTool.factCheck,
        GemmellTool.researchDebt,
        GemmellTool.sensitivityQuestions,
      }.contains(t),
    ),
  ];
  ExportDecision<GemmellTool> route(List<GemmellTool> remaining, int index) {
    if (index == groups.length) return choose(remaining);
    final yes = remaining.where(groups[index].$2).toList(),
        no = remaining.where((t) => !groups[index].$2(t)).toList();
    if (yes.isEmpty) return route(no, index + 1);
    if (no.isEmpty) return choose(yes);
    return ExportDecision.question(
      groups[index].$1,
      choose(yes),
      route(no, index + 1),
    );
  }

  return route(tools, 0);
}

Future<GemmellTool?> showGemmellWizard(
  BuildContext context,
  List<GemmellTool> tools,
  String name,
) => showDialog<GemmellTool>(
  context: context,
  builder: (_) => ExportWizard(
    title: '$name Wizard',
    root: gemmellDecision(tools),
    confirmLabel: 'Use this tool',
    note: 'This prepares a prompt to copy into your chatbot. Suggestions stay separate from your manuscript.',
  ),
);

enum DiscoveryScope { scene, chapter, manuscript }

Future<DiscoveryScope?> chooseDiscoveryScope(BuildContext context) =>
    showDialog<DiscoveryScope>(
      context: context,
      builder: (_) => const ExportWizard(
        title: 'Discover encyclopedia entries',
        confirmLabel: 'Prepare discovery prompt',
        root: ExportDecision.question(
          'Should I look through the entire manuscript?',
          ExportDecision.result(
            'Scope: entire manuscript',
            DiscoveryScope.manuscript,
          ),
          ExportDecision.question(
            'Should I include every scene in the current chapter?',
            ExportDecision.result(
              'Scope: current chapter',
              DiscoveryScope.chapter,
            ),
            ExportDecision.result('Scope: current scene', DiscoveryScope.scene),
          ),
        ),
      ),
    );

String discoveryMaterial(
  StoryProject project,
  StoryScene current,
  DiscoveryScope scope,
) {
  final out = StringBuffer();
  for (final chapter in project.sections) {
    if (scope == DiscoveryScope.chapter && !chapter.scenes.contains(current)) {
      continue;
    }
    final scenes = chapter.scenes.where(
      (s) => scope != DiscoveryScope.scene || s == current,
    );
    if (scenes.isEmpty) continue;
    out.writeln('Chapter: ${chapter.title}');
    for (final scene in scenes) {
      out.writeln('Scene: ${scene.title} [${scene.id}]\n${scene.content}\n');
    }
  }
  return out.toString();
}

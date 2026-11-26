part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _ReportFormDialog extends StatefulWidget {
  const _ReportFormDialog({
    required this.report,
    required this.role,
    required this.diagnoses,
  });

  final CropReport report;
  final SihamaRole role;
  final List<DiagnosisReference> diagnoses;

  @override
  State<_ReportFormDialog> createState() => _ReportFormDialogState();
}

class _ReportFormDialogState extends State<_ReportFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _locationController = TextEditingController(
    text: widget.report.location,
  );
  late final _descriptionController = TextEditingController(
    text: widget.report.description,
  );
  late final _recommendationController = TextEditingController(
    text: widget.report.recommendation ?? '',
  );
  late String _crop = widget.report.crop;
  late String _status = widget.report.status;
  late int? _diagnosisReferenceId = widget.report.diagnosisReferenceId;
  String? _diagnosis;

  bool get _isAdviser => widget.role == SihamaRole.penyuluh;

  @override
  void initState() {
    super.initState();
    if (_diagnosisReferenceId == null && widget.report.diagnosis != null) {
      for (final reference in widget.diagnoses) {
        if (reference.name == widget.report.diagnosis) {
          _diagnosisReferenceId = reference.id;
          break;
        }
      }
    }
    _diagnosis = widget.report.diagnosis;
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _recommendationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit laporan'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.report.crop != _unspecifiedCrop) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _crop,
                    decoration: _inputDecoration('Tanaman'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Padi sawah',
                        child: Text('Padi sawah'),
                      ),
                      DropdownMenuItem(value: 'Padi', child: Text('Padi')),
                      DropdownMenuItem(value: 'Cabai', child: Text('Cabai')),
                      DropdownMenuItem(value: 'Tomat', child: Text('Tomat')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _crop = value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _locationController,
                  decoration: _inputDecoration('Lokasi atau nama petak'),
                  validator: _requiredValue,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _inputDecoration('Gejala tanaman'),
                  validator: _requiredValue,
                ),
                const SizedBox(height: 12),
                if (_isAdviser) ...[
                  DropdownButtonFormField<int?>(
                    initialValue: _diagnosisReferenceId,
                    decoration: _inputDecoration('Diagnosis penyakit'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Belum ditentukan'),
                      ),
                      ...widget.diagnoses.map(
                        (reference) => DropdownMenuItem<int?>(
                          value: reference.id,
                          child: Text(
                            reference.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _diagnosisReferenceId = value;
                        _diagnosis = value == null
                            ? null
                            : widget.diagnoses
                                  .firstWhere(
                                    (reference) => reference.id == value,
                                  )
                                  .name;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recommendationController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _inputDecoration('Rekomendasi penanganan'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isAdviser)
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _inputDecoration('Status laporan'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Diajukan',
                        child: Text('Diajukan'),
                      ),
                      DropdownMenuItem(
                        value: 'Ditinjau',
                        child: Text('Ditinjau'),
                      ),
                      DropdownMenuItem(
                        value: 'Selesai Ditinjau',
                        child: Text('Selesai Ditinjau'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _status = value);
                    },
                  )
                else
                  InputDecorator(
                    decoration: _inputDecoration('Status laporan'),
                    child: Text(_status),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              CropReport(
                id: widget.report.id,
                crop: _crop,
                location: _locationController.text.trim(),
                description: _descriptionController.text.trim(),
                date: widget.report.date,
                status: _status,
                photoBytes: widget.report.photoBytes,
                diagnosis: _isAdviser ? _diagnosis : widget.report.diagnosis,
                diagnosisReferenceId: _isAdviser
                    ? _diagnosisReferenceId
                    : widget.report.diagnosisReferenceId,
                adviserId: widget.report.adviserId,
                symptomIds: widget.report.symptomIds,
                recommendation: _isAdviser
                    ? _recommendationController.text.trim()
                    : widget.report.recommendation,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

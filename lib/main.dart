import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GasolineProCalculator(),
    ));

class GasolineProCalculator extends StatefulWidget {
  @override
  _GasolineProCalculatorState createState() => _GasolineProCalculatorState();
}

class _GasolineProCalculatorState extends State<GasolineProCalculator> {
  final int rowCount = 8;
  late List<Map<String, TextEditingController>> rowsData;
  final ScreenshotController screenshotController = ScreenshotController();
  
  String productGrade = "95"; 

  double totalLevel = 0.0, ethyl135 = 0.0, finalDen = 0.0, finalAr = 0.0, 
         finalBen = 0.0, finalRvp = 0.0, finalOle = 0.0, finalS = 0.0, finalOct = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    rowsData = List.generate(rowCount, (index) {
      var row = <String, TextEditingController>{};
      ['tank', 'prod', 'level', 'oct', 'sens', 'den', 'ar', 'ben', 'ole', 'rvp', 's']
          .forEach((key) {
        row[key] = TextEditingController(text: (key == 'tank' || key == 'prod') ? '' : '0');
        row[key]!.addListener(() {
          _saveData(index, key, row[key]!.text);
          _calculateAll();
        });
      });
      return row;
    });
    _loadSavedData();
  }

  _saveData(int index, String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('row_${index}_$key', value);
  }

  _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < rowCount; i++) {
      rowsData[i].forEach((key, controller) {
        controller.text = prefs.getString('row_${i}_$key') ?? controller.text;
      });
    }
    _calculateAll();
  }

  void _calculateAll() {
    double tLvl = 0, wOct = 0, wSens = 0, wDen = 0, wAr = 0, wBen = 0, wOle = 0, wS = 0, rvpSum = 0;
    double sumRJ = 0, sumO2 = 0;

    for (var r in rowsData) tLvl += double.tryParse(r["level"]!.text) ?? 0;

    if (tLvl > 0) {
      for (var r in rowsData) {
        double l = double.tryParse(r["level"]!.text) ?? 0;
        double ratio = l / tLvl;
        double oct = double.tryParse(r["oct"]!.text) ?? 0;
        double sens = double.tryParse(r["sens"]!.text) ?? 0;
        double den = double.tryParse(r["den"]!.text) ?? 0;
        double ar = double.tryParse(r["ar"]!.text) ?? 0;
        double ben = double.tryParse(r["ben"]!.text) ?? 0;
        double ole = double.tryParse(r["ole"]!.text) ?? 0;
        double rvp = double.tryParse(r["rvp"]!.text) ?? 0;
        double s = double.tryParse(r["s"]!.text) ?? 0;

        wOct += ratio * oct; wSens += ratio * sens; wDen += ratio * den;
        wAr += ratio * ar; wBen += ratio * ben; wOle += ratio * ole; wS += ratio * s;
        sumRJ += ratio * oct * sens; sumO2 += ratio * pow(ole, 2);
        if (rvp > 0) rvpSum += ratio * pow(rvp, 1.25);
      }
      ethyl135 = wOct + (0.03324 * (sumRJ - (wOct * wSens))) + (0.00085 * (sumO2 - pow(wOle, 2)));
    }

    setState(() {
      totalLevel = tLvl; finalOct = wOct; finalDen = wDen; finalAr = wAr;
      finalBen = wBen; finalOle = wOle; finalS = wS;
      finalRvp = tLvl > 0 ? pow(rvpSum, 1 / 1.25).toDouble() : 0;
    });
  }

  Color _getSpecColor(String type, double value) {
    bool isOk = true;
    if (productGrade == "95") {
      if (type == "OCT") isOk = value >= 95;
      if (type == "BEN") isOk = value <= 0.9;
      if (type == "AR") isOk = value <= 33;
      if (type == "RVP") isOk = value <= 0.7;
    } else {
      if (type == "OCT") isOk = value >= 92;
      if (type == "BEN") isOk = value <= 0.95;
      if (type == "AR") isOk = value <= 35;
    }
    return isOk ? Colors.greenAccent : Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: Text("Gasoline Blending Calculator", style: TextStyle(fontSize: 16, color: Colors.white)),
        actions: [
          DropdownButton<String>(
            value: productGrade,
            dropdownColor: Colors.blueGrey[900],
            underline: Container(),
            style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
            items: ["92", "95"].map((s) => DropdownMenuItem(value: s, child: Text("Grade $s  "))).toList(),
            onChanged: (v) => setState(() => productGrade = v!),
          ),
          IconButton(icon: Icon(Icons.print_rounded, color: Colors.greenAccent), onPressed: _showRecipeDialog)
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  horizontalMargin: 5,
                  headingRowHeight: 35,
                  dataRowHeight: 35,
                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey[800]),
                  border: TableBorder.all(color: Colors.grey[800]!),
                  columns: ['Tank', 'Prod', 'Level', 'Oct', 'Den', 'Ar', 'Ben', 'Ole', 'RVP', 'S']
                      .map((h) => DataColumn(label: Text(h, style: TextStyle(color: Colors.white, fontSize: 10)))).toList(),
                  rows: [
                    ...rowsData.map((row) => DataRow(cells: [
                      _inputCell(row['tank']!, 45, true), _inputCell(row['prod']!, 60, true),
                      _inputCell(row['level']!, 45, false), _inputCell(row['oct']!, 35, false),
                      _inputCell(row['den']!, 55, false), _inputCell(row['ar']!, 35, false),
                      _inputCell(row['ben']!, 35, false), _inputCell(row['ole']!, 35, false),
                      _inputCell(row['rvp']!, 40, false), _inputCell(row['s']!, 35, false),
                    ])).toList(),
                    DataRow(color: MaterialStateProperty.all(Colors.grey[900]), cells: [
                      DataCell(Text("SPEC", style: TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold))),
                      DataCell(Text(productGrade, style: TextStyle(color: Colors.white, fontSize: 10))),
                      DataCell(Text("")), 
                      DataCell(_specBox(ethyl135.toStringAsFixed(1), _getSpecColor("OCT", ethyl135))),
                      DataCell(Text("")), 
                      DataCell(_specBox(finalAr.toStringAsFixed(1), _getSpecColor("AR", finalAr))),
                      DataCell(_specBox(finalBen.toStringAsFixed(2), _getSpecColor("BEN", finalBen))),
                      DataCell(Text("")), 
                      DataCell(_specBox(finalRvp.toStringAsFixed(2), _getSpecColor("RVP", finalRvp))),
                      DataCell(Text("")), 
                    ])
                  ],
                ),
              ),
            ),
          ),
          _buildSummary(),
        ],
      ),
    );
  }

  Widget _specBox(String t, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.2), border: Border.all(color: c)),
    child: Text(t, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  DataCell _inputCell(TextEditingController c, double w, bool isTxt) => DataCell(
    Container(width: w, child: TextField(
      controller: c, 
      textAlign: TextAlign.center, 
      keyboardType: isTxt ? TextInputType.text : TextInputType.number,
      style: TextStyle(color: Colors.white, fontSize: 10),
      decoration: InputDecoration(border: InputBorder.none),
    )),
  );

  Widget _buildSummary() => Container(
    color: Colors.blueGrey[900],
    padding: EdgeInsets.all(10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _stat("TOTAL LVL", totalLevel.toStringAsFixed(1), Colors.white),
        _stat("ETHYL OCT", ethyl135.toStringAsFixed(2), Colors.orangeAccent),
        _stat("RVP", finalRvp.toStringAsFixed(2), Colors.purpleAccent),
      ],
    ),
  );

  Widget _stat(String l, String v, Color c) => Column(children: [
    Text(l, style: TextStyle(color: Colors.grey, fontSize: 10)),
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.bold)),
  ]);

  void _showRecipeDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      content: Screenshot(
        controller: screenshotController,
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(20),
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Gasoline Blending Calculator", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey[900])),
              Text("App by Mohammed Nofal", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500)),
              SizedBox(height: 10),
              Divider(thickness: 1.5),
              Text("Components Table", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: Colors.black12),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey[200]),
                    children: [
                      _th("Tank"), _th("Product"), _th("Level"), _th("Octane")
                    ]
                  ),
                  ...rowsData.where((r) => (double.tryParse(r['level']!.text) ?? 0) > 0).map((r) => TableRow(
                    children: [
                      _td(r['tank']!.text), _td(r['prod']!.text), _td(r['level']!.text), _td(r['oct']!.text)
                    ]
                  )).toList(),
                ],
              ),
              Divider(height: 30),
              _recipeRow("FINAL OCTANE (ETHYL):", ethyl135.toStringAsFixed(2)),
              _recipeRow("TOTAL LEVEL (cm):", totalLevel.toStringAsFixed(1)),
              _recipeRow("FINAL DENSITY:", finalDen.toStringAsFixed(4)),
              _recipeRow("FINAL AR%:", finalAr.toStringAsFixed(1)),
              _recipeRow("FINAL BENZENE%:", finalBen.toStringAsFixed(2)),
              _recipeRow("FINAL RVP:", finalRvp.toStringAsFixed(2)),
              SizedBox(height: 15),
              Text("Generated on: ${DateTime.now().toString().substring(0,16)}", style: TextStyle(fontSize: 8, color: Colors.grey)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900]),
          onPressed: _saveImg, 
          child: Text("Save to Gallery", style: TextStyle(color: Colors.white))
        )
      ],
    ));
  }

  Widget _th(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)));
  Widget _td(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 10)));

  Widget _recipeRow(String l, String v) => Padding(
    padding: EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontSize: 11)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey[800]))]),
  );

  void _saveImg() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await ImageGallerySaver.saveImage(image, name: "GBC_Report_${DateTime.now().millisecondsSinceEpoch}");
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text("Report Saved Successfully!")));
    }
  }
}

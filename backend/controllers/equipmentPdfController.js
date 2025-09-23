const PDFDocument = require('pdfkit');
const Equipment = require('../models/Equipment');

const generateEquipmentPDF = async (req, res) => {
  try {
    const {
      // Filter options
      category = 'All',
      condition = 'All',
      maintenanceDueOnly = false,
      calibrationDueOnly = false,
      warrantyExpiringOnly = false,
      maintenanceDueWithin = 30,
      calibrationDueWithin = 30,
      search = '',

      // Content sections
      includeBasicInfo = true,
      includeMaintenanceInfo = true,
      includeCalibrationInfo = true,
      includePurchaseWarranty = false,
      includeManufacturerInfo = true,

      // Additional options
      includeStatistics = true,
      showStatusColors = true
    } = req.body;

    // Get filtered equipment
    const equipment = await Equipment.getFilteredEquipment({
      category,
      condition,
      maintenanceDueOnly,
      calibrationDueOnly,
      warrantyExpiringOnly,
      maintenanceDueWithin,
      calibrationDueWithin,
      search
    });

    // Get equipment analysis if requested
    let equipmentAnalysis = null;
    if (includeStatistics) {
      equipmentAnalysis = await Equipment.getEquipmentAnalysis();
    }

    // Create PDF document
    const doc = new PDFDocument({ margin: 50 });

    // Set response headers
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename=equipment-inventory.pdf');

    // Pipe the PDF to response
    doc.pipe(res);

    // Generate PDF content
    await generateEquipmentPDFContent(doc, equipment, equipmentAnalysis, {
      includeBasicInfo,
      includeMaintenanceInfo,
      includeCalibrationInfo,
      includePurchaseWarranty,
      includeManufacturerInfo,
      includeStatistics,
      showStatusColors,
      filters: { category, condition, maintenanceDueOnly, calibrationDueOnly, search }
    });

    doc.end();

  } catch (error) {
    console.error('Equipment PDF Generation Error:', error);
    res.status(500).json({ error: error.message });
  }
};

async function generateEquipmentPDFContent(doc, equipment, equipmentAnalysis, options) {
  // Professional Header
  doc.fontSize(10).fillColor('#7f8c8d');
  doc.text('Chemistry Laboratory Management System', { align: 'center' });
  doc.text('Equipment Inventory & Maintenance Report', { align: 'center' });
  doc.moveDown(0.5);

  doc.fontSize(24).fillColor('#2c3e50').text('EQUIPMENT INVENTORY REPORT', { align: 'center' });
  doc.fontSize(10).fillColor('#7f8c8d').text(`Generated on: ${new Date().toLocaleDateString()} at ${new Date().toLocaleTimeString()}`, { align: 'center' });
  
  // Add horizontal line
  doc.moveTo(50, doc.y + 10).lineTo(doc.page.width - 50, doc.y + 10).stroke('#bdc3c7');
  doc.moveDown(2);

  // Enhanced Statistics Section
  if (options.includeStatistics && equipmentAnalysis) {
    const statsBoxTop = doc.y;
    doc.rect(50, statsBoxTop, doc.page.width - 100, 140).fill('#ecf0f1');
    
    doc.fontSize(16).fillColor('#2c3e50').text('EQUIPMENT SUMMARY', 70, statsBoxTop + 15);
    
    const leftMargin = 70;
    let currentStatsY = statsBoxTop + 45;
    const lineHeight = 18;
    
    doc.fontSize(12).fillColor('#34495e');
    
    // Display stats
    doc.text(`Total Equipment:`, leftMargin, currentStatsY);
    doc.fillColor('#27ae60').text(`${equipmentAnalysis.total_equipment}`, leftMargin + 200, currentStatsY);
    currentStatsY += lineHeight;
    
    doc.fillColor('#34495e').text(`Needs Attention:`, leftMargin, currentStatsY);
    doc.fillColor('#e74c3c').text(`${equipmentAnalysis.needs_attention_count}`, leftMargin + 200, currentStatsY);
    currentStatsY += lineHeight;
    
    doc.fillColor('#34495e').text(`Maintenance Due:`, leftMargin, currentStatsY);
    doc.fillColor('#f39c12').text(`${equipmentAnalysis.maintenance_due_count}`, leftMargin + 200, currentStatsY);
    currentStatsY += lineHeight;
    
    doc.fillColor('#34495e').text(`Calibration Due:`, leftMargin, currentStatsY);
    doc.fillColor('#9b59b6').text(`${equipmentAnalysis.calibration_due_count}`, leftMargin + 200, currentStatsY);
    currentStatsY += lineHeight;
    
    doc.fillColor('#34495e').text(`Warranty Expiring:`, leftMargin, currentStatsY);
    doc.fillColor('#e67e22').text(`${equipmentAnalysis.warranty_expiring_count}`, leftMargin + 200, currentStatsY);
    
    doc.y = statsBoxTop + 150;
    doc.moveDown(1);
  }

  // Add legend
  if (equipment.some(eq => eq.is_maintenance_due || eq.is_calibration_due || eq.is_warranty_expiring)) {
    doc.fontSize(10).fillColor('#2c3e50').text('Legend:', 70, doc.y);
    doc.moveDown(0.3);
    
    doc.rect(70, doc.y, 10, 10).fill('#f39c12');
    doc.fillColor('#2c3e50').text('Maintenance Due', 90, doc.y + 2);
    
    doc.rect(180, doc.y, 10, 10).fill('#9b59b6');
    doc.text('Calibration Due', 200, doc.y + 2);
    
    doc.rect(300, doc.y, 10, 10).fill('#e67e22');
    doc.text('Warranty Expiring', 320, doc.y + 2);
    
    doc.moveDown(1);
  }

  // Enhanced Table Section
  doc.fontSize(16).fillColor('#2c3e50').text('EQUIPMENT DETAILS');
  doc.moveDown(0.5);

  const columns = getEquipmentColumns(options);
  const tableStartY = doc.y;
  const rowHeight = 30;
  const tableWidth = doc.page.width - 100;

  // Define column widths
  const getEquipmentColumnWidths = (columns) => {
    const widthMap = {
      'Equipment Name': 85,
      'Category': 65,
      'Condition': 60,
      'Location': 70,
      'Serial Number': 70,
      'Manufacturer': 70,
      'Model': 60,
      'Last Maintenance': 75,
      'Next Maintenance': 75,
      'Schedule (Days)': 60,
      'Last Calibration': 75,
      'Next Calibration': 75,
      'Purchase Date': 70,
      'Warranty Expiry': 75,
      'Status': 60
    };
    
    return columns.map(col => widthMap[col.header] || 65);
  };

  const colWidths = getEquipmentColumnWidths(columns);
  const totalCalculatedWidth = colWidths.reduce((sum, width) => sum + width, 0);
  const scaleFactor = tableWidth / totalCalculatedWidth;
  const scaledWidths = colWidths.map(width => width * scaleFactor);

  // Table header
  doc.rect(50, tableStartY, tableWidth, rowHeight).fill('#27ae60');
  
  doc.fontSize(9).fillColor('white');
  let currentX = 50;
  columns.forEach((col, index) => {
    doc.text(col.header, currentX + 5, tableStartY + 10, { 
      width: scaledWidths[index] - 10, 
      align: 'left',
      lineBreak: false,
      ellipsis: true
    });
    currentX += scaledWidths[index];
  });

  let currentY = tableStartY + rowHeight;

  // Table rows
  equipment.forEach((eq, index) => {
    // Check for new page
    if (currentY > doc.page.height - 100) {
      doc.addPage();
      currentY = 50;
      
      // Redraw header
      doc.rect(50, currentY, tableWidth, rowHeight).fill('#27ae60');
      doc.fontSize(9).fillColor('white');
      let headerX = 50;
      columns.forEach((col, colIndex) => {
        doc.text(col.header, headerX + 5, currentY + 10, { 
          width: scaledWidths[colIndex] - 10, 
          align: 'left',
          lineBreak: false,
          ellipsis: true
        });
        headerX += scaledWidths[colIndex];
      });
      currentY += rowHeight;
    }

    // Row background
    const rowColor = index % 2 === 0 ? '#ffffff' : '#f8f9fa';
    doc.rect(50, currentY, tableWidth, rowHeight).fill(rowColor);

    // Determine text color based on status
    let textColor = '#2c3e50';
    if (eq.is_maintenance_due) {
      textColor = '#f39c12';
    } else if (eq.is_calibration_due) {
      textColor = '#9b59b6';
    } else if (eq.is_warranty_expiring) {
      textColor = '#e67e22';
    }

    doc.fontSize(8).fillColor(textColor);

    // Draw cells
    let cellX = 50;
    columns.forEach((col, colIndex) => {
      const value = getEquipmentColumnValue(eq, col.key);
      doc.text(value, cellX + 5, currentY + 10, {
        width: scaledWidths[colIndex] - 10,
        height: rowHeight - 6,
        ellipsis: true,
        align: 'left',
        lineBreak: false
      });
      cellX += scaledWidths[colIndex];
    });

    currentY += rowHeight;
  });

  // Footer
  doc.fontSize(8).fillColor('#7f8c8d');
  const footerY = doc.page.height - 30;
  doc.text(`Equipment Management System | Report contains ${equipment.length} items | Generated: ${new Date().toLocaleString()}`, 
    50, footerY, { width: doc.page.width - 100, align: 'center' });
}

function getEquipmentColumns(options) {
  const columns = [];

  if (options.includeBasicInfo) {
    columns.push(
      { key: 'name', header: 'Equipment Name' },
      { key: 'category', header: 'Category' },
      { key: 'condition', header: 'Condition' },
      { key: 'location', header: 'Location' }
    );
  }

  if (options.includeManufacturerInfo) {
    columns.push(
      { key: 'serial_number', header: 'Serial Number' },
      { key: 'manufacturer', header: 'Manufacturer' },
      { key: 'model', header: 'Model' }
    );
  }

  if (options.includeMaintenanceInfo) {
    columns.push(
      { key: 'last_maintenance_date', header: 'Last Maintenance' },
      { key: 'next_maintenance_date', header: 'Next Maintenance' },
      { key: 'maintenance_schedule', header: 'Schedule (Days)' }
    );
  }

  if (options.includeCalibrationInfo) {
    columns.push(
      { key: 'calibration_date', header: 'Last Calibration' },
      { key: 'next_calibration_date', header: 'Next Calibration' }
    );
  }

  if (options.includePurchaseWarranty) {
    columns.push(
      { key: 'purchase_date', header: 'Purchase Date' },
      { key: 'warranty_expiry', header: 'Warranty Expiry' }
    );
  }

  return columns;
}

function getEquipmentColumnValue(equipment, key) {
  switch(key) {
    case 'last_maintenance_date':
    case 'next_maintenance_date':
    case 'calibration_date':
    case 'next_calibration_date':
    case 'purchase_date':
    case 'warranty_expiry':
      return equipment[key] ? new Date(equipment[key]).toLocaleDateString() : 'N/A';
    case 'maintenance_schedule':
      return `${equipment.maintenance_schedule} days`;
    default:
      return equipment[key] || 'N/A';
  }
}

module.exports = { generateEquipmentPDF };
/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtend.ide.tests.macros

import java.io.BufferedInputStream
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.jar.Manifest
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IFolder
import org.eclipse.jdt.core.IJavaProject
import org.eclipse.jdt.core.JavaCore
import org.eclipse.xtext.junit4.internal.StopwatchRule
import org.eclipse.xtext.util.StringInputStream
import org.junit.After
import org.junit.Rule
import org.junit.Test

import static org.eclipse.xtend.ide.tests.WorkbenchTestHelper.*
import static org.eclipse.xtext.junit4.ui.util.IResourcesSetupUtil.*
import org.eclipse.core.runtime.NullProgressMonitor
import com.google.common.io.CharStreams
import java.io.InputStreamReader
import org.junit.Ignore

/**
 * @author Sven Efftinge - Initial contribution and API
 */
class MoreActiveAnnotationsTest {

	@Rule public StopwatchRule stopwatch = new StopwatchRule(true);

	@After def tearDown() throws Exception {
		cleanWorkspace();
	}
	
	@Test def void testBug461761() {
		val macroProject = JavaCore.create(createPluginProject("macroProject"))
		macroProject.newSource("annotation/DItemMini.xtend", '''
			package annotation
			
			import org.eclipse.xtend.lib.macro.AbstractClassProcessor
			import org.eclipse.xtend.lib.macro.Active
			import org.eclipse.xtend.lib.macro.RegisterGlobalsContext
			import org.eclipse.xtend.lib.macro.declaration.ClassDeclaration
			import static extension com.google.common.io.Files.append
			
			@Active(DItemMiniProcessor)
			annotation DItemMini {
			}
			
			class DItemMiniProcessor extends AbstractClassProcessor {
			
				override doRegisterGlobals(ClassDeclaration annotatedClass, extension RegisterGlobalsContext context) {
					registerClass(annotatedClass.qualifiedName + "Item")
				}
			
			}
		''')
		macroProject.addExportedPackage("annotation")
		waitForAutoBuild
				
		val userProject = JavaCore.create(
			createPluginProject("userProject", "com.google.inject", "org.eclipse.xtend.lib",
				"org.eclipse.xtend.core.tests", "org.eclipse.xtext.xbase.lib", "org.eclipse.xtend.ide.tests.data", "org.junit", "macroProject"))
		userProject.newSource("client/UserCode.xtend", '''
			package client
			@annotation.DItemMini
			class UserCode{
				UserCodeItem item
			}
		''')
		waitForAutoBuild
		assertNoErrorsInWorkspace
	}
	
	@Test def void testBug461761_01() {
		val macroProject = JavaCore.create(createPluginProject("macroProject"))
		macroProject.newSource("annotation/DItemMini.xtend", '''
			package annotation
			
			import org.eclipse.xtend.lib.macro.AbstractClassProcessor
			import org.eclipse.xtend.lib.macro.Active
			import org.eclipse.xtend.lib.macro.RegisterGlobalsContext
			import org.eclipse.xtend.lib.macro.declaration.ClassDeclaration
			
			@Active(DItemMiniProcessor)
			annotation DItemMini {
				String value
			}
			
			class DItemMiniProcessor extends AbstractClassProcessor {
			
				override doRegisterGlobals(ClassDeclaration annotatedClass, extension RegisterGlobalsContext context) {
					val suffix = annotatedClass.annotations.head.getValue("value")
					registerClass(annotatedClass.qualifiedName + suffix)
				}
			
			}
		''')
		macroProject.newSource("annotation/StaticFeatures.xtend", '''
			package annotation
			
			class StaticFeatures {
				public final static String BAR = "Bar"
				public final static String FOOBAR = "Foo" + BAR 
			}
		''')
		macroProject.addExportedPackage("annotation")
		waitForAutoBuild
				
		val userProject = JavaCore.create(
			createPluginProject("userProject", "com.google.inject", "org.eclipse.xtend.lib",
				"org.eclipse.xtend.core.tests", "org.eclipse.xtext.xbase.lib", "org.eclipse.xtend.ide.tests.data", "org.junit", "macroProject"))
		userProject.newSource("client/UserCode.xtend", '''
			package client
			
			import static annotation.StaticFeatures.FOOBAR
			
			@annotation.DItemMini(FOOBAR)
			class UserCode{
				UserCodeFooBar item
			}
		''')
		waitForAutoBuild
		assertNoErrorsInWorkspace
	}
	
	@Test def void testBug461761_02() {
		val macroProject = JavaCore.create(createPluginProject("macroProject"))
		macroProject.newSource("annotation/DItemMini.xtend", '''
			package annotation
			
			import org.eclipse.xtend.lib.macro.AbstractClassProcessor
			import org.eclipse.xtend.lib.macro.Active
			import org.eclipse.xtend.lib.macro.RegisterGlobalsContext
			import org.eclipse.xtend.lib.macro.declaration.*
			
			@Active(DItemMiniProcessor)
			annotation DItemMini {
				MyEnum[] enumVals = #[MyEnum.VAL1]
				Class<?> someType = MyEnum
			}
			
			class DItemMiniProcessor extends AbstractClassProcessor {
			
				override doRegisterGlobals(ClassDeclaration annotatedClass, extension RegisterGlobalsContext context) {
					val suffix = annotatedClass.annotations.head.getValue("someType") as TypeReference
					val enums = annotatedClass.annotations.head.getValue("enumVals") as EnumerationValueDeclaration[]
					registerClass(annotatedClass.qualifiedName + suffix.simpleName + enums.map[simpleName].join)
				}
			
			}
		''')
		macroProject.newSource("annotation/StaticFeatures.xtend", '''
			package annotation
			
			enum MyEnum {
				VAL1, VAL2
			}
		''')
		macroProject.addExportedPackage("annotation")
		waitForAutoBuild
				
		val userProject = JavaCore.create(
			createPluginProject("userProject", "com.google.inject", "org.eclipse.xtend.lib",
				"org.eclipse.xtend.core.tests", "org.eclipse.xtext.xbase.lib", "org.eclipse.xtend.ide.tests.data", "org.junit", "macroProject"))
		userProject.newSource("client/UserCode.xtend", '''
			package client
			
			import annotation.*
			import static annotation.MyEnum.VAL2
			
			@DItemMini
			class Defaults {
				DefaultsMyEnumVAL1 field
			}
			
			@DItemMini(enumVals=#[VAL2, MyEnum.VAL1], someType=typeof(Defaults))
			class Explicit {
				ExplicitDefaultsVAL2VAL1 field
			}
			
			@DItemMini(someType=Object)
			class Mixed {
				MixedObjectVAL1 field
			}
		''')
		waitForAutoBuild
		assertNoErrorsInWorkspace
	}
	
	@Ignore("It fails because JDT doesn't provide annotation values of annotation.MyClass. For some unknown reason the binding is set to null which makes JDT filtering them out.")
	@Test def void testBug461761_03() {
		val macroProject = JavaCore.create(createPluginProject("macroProject"))
		macroProject.newSource("annotation/DItemMini.xtend", '''
			package annotation
			
			import org.eclipse.xtend.lib.macro.AbstractClassProcessor
			import org.eclipse.xtend.lib.macro.Active
			import org.eclipse.xtend.lib.macro.RegisterGlobalsContext
			import org.eclipse.xtend.lib.macro.declaration.*
			
			@Active(DItemMiniProcessor)
			annotation DItemMini {
				MyEnum[] enumVals = #[MyEnum.VAL1]
				Class<?> someType = MyEnum
			}
			
			class DItemMiniProcessor extends AbstractClassProcessor {
			
				override doRegisterGlobals(ClassDeclaration annotatedClass, extension RegisterGlobalsContext context) {
					val annotationRef = (findUpstreamType("annotation.MyClass") as ClassDeclaration).annotations.head
					val suffix = annotationRef.getValue("someType") as TypeReference
					val enums = annotationRef.getValue("enumVals") as EnumerationValueDeclaration[]
					registerClass(annotatedClass.qualifiedName + suffix.simpleName + enums.map[simpleName].join)
				}
			
			}
		''')
		macroProject.newSource("annotation/StaticFeatures.xtend", '''
			package annotation
			
			enum MyEnum {
				VAL1, VAL2
			}
		''')
		macroProject.newSource("annotation/MyClass.java", '''
			package annotation;
			
			import static annotation.MyEnum.*;
			
			@DItemMini(enumVals={VAL2, VAL2}, someType=String.class) 
			public class MyClass {
			}
		''')
		macroProject.addExportedPackage("annotation")
		waitForAutoBuild
				
		val userProject = JavaCore.create(
			createPluginProject("userProject", "com.google.inject", "org.eclipse.xtend.lib",
				"org.eclipse.xtend.core.tests", "org.eclipse.xtext.xbase.lib", "org.eclipse.xtend.ide.tests.data", "org.junit", "macroProject"))
		
		userProject.newSource("client/UserCode.xtend", '''
			package client
			
			import annotation.*
			import static annotation.MyEnum.VAL2
			
			@DItemMini
			class Processed {
				ProcessedStringVAL2VAL1 field
			}
		''')
		waitForAutoBuild
		assertNoErrorsInWorkspace
	}
	
	@Test def void testStaticInitializers() {
		val macroProject = JavaCore.create(createPluginProject("macroProject"))
		macroProject.newSource("annotation/MyAA.xtend", '''
			package annotation
			
			import org.eclipse.xtend.lib.macro.AbstractClassProcessor
			import org.eclipse.xtend.lib.macro.Active
			import org.eclipse.xtend.lib.macro.TransformationContext
			import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
			import org.eclipse.xtend.lib.macro.declaration.Visibility
			
			@Active(MyAAProcessor)
			annotation MyAA {
			}
			
			class MyAAProcessor extends AbstractClassProcessor {
				
				override doTransform(MutableClassDeclaration annotatedClass, extension TransformationContext context) {
					annotatedClass.addField('CONSTANT_INT') [
						type = primitiveInt
						visibility = Visibility.PUBLIC
						constantValueAsInt = 42
					]
					annotatedClass.addField('CONSTANT_LONG') [
						type = primitiveLong
						visibility = Visibility.PUBLIC
						constantValueAsLong = 42
					]
					annotatedClass.addField('CONSTANT_FLOAT') [
						type = primitiveFloat
						visibility = Visibility.PUBLIC
						constantValueAsFloat = 42.34f
					]
					annotatedClass.addField('CONSTANT_DOUBLE') [
						type = primitiveDouble
						visibility = Visibility.PUBLIC
						constantValueAsDouble = 42.11d
					]
					annotatedClass.addField('CONSTANT_CHAR') [
						type = primitiveChar
						visibility = Visibility.PUBLIC
						constantValueAsChar = '\n'
					]
					annotatedClass.addField('CONSTANT_STRING') [
						type = string
						visibility = Visibility.PUBLIC
						constantValueAsString = "\n\t\\all"
					]
				}
			}
		''')
		macroProject.addExportedPackage("annotation")
		waitForAutoBuild()
				
		val userProject = JavaCore.create(
			createPluginProject("userProject", "com.google.inject", "org.eclipse.xtend.lib",
				"org.eclipse.xtend.core.tests", "org.eclipse.xtext.xbase.lib", "org.eclipse.xtend.ide.tests.data", "org.junit", "macroProject"))
		userProject.newSource("client/A.xtend", '''
			package client
			
			@SuppressWarnings(client.sub.B.CONSTANT_STRING)
			class A {
			}
		''')
		userProject.newSource("client/sub/B.xtend", '''
			package client.sub
			
			import annotation.MyAA
			
			@MyAA
			class B {
			}
		''')
		
		cleanBuild
		waitForBuild(new NullProgressMonitor)
		val file = userProject.project.findMember("xtend-gen/client/sub/B.java") as IFile
		val contents = CharStreams.toString(new InputStreamReader(file.contents))
		assertEquals('''
			package client.sub;
			
			import annotation.MyAA;
			
			@MyAA
			@SuppressWarnings("all")
			public class B {
			  public final static int CONSTANT_INT = 42;
			  
			  public final static long CONSTANT_LONG = 42L;
			  
			  public final static float CONSTANT_FLOAT = 42.34f;
			  
			  public final static double CONSTANT_DOUBLE = 42.11d;
			  
			  public final static char CONSTANT_CHAR = '\n';
			  
			  public final static String CONSTANT_STRING = "\n\t\\all";
			}
		'''.toString, contents)
		assertNoErrorsInWorkspace
	}
	
	private def IFile newSource(IJavaProject it, String fileName, String contents) {
		val result = it.project.getFile("src/" + fileName)
		var parent = result.parent
		while (!parent.exists) {
			(parent as IFolder).create(true, false, null)
		}
		result.create(new StringInputStream(contents), true, null)
		return result
	}

	private def void addExportedPackage(IJavaProject pluginProject, String ... exportedPackages) {
		val manifestFile = pluginProject.project.getFile("META-INF/MANIFEST.MF")
		val manifestContent = manifestFile.contents
		val manifest = try {
			new Manifest(manifestContent)
		} finally {
			manifestContent.close
		}
		val attrs = manifest.getMainAttributes()
		if (attrs.containsKey("Export-Package")) {
			attrs.putValue("Export-Package", attrs.get("Export-Package") + "," + exportedPackages.join(","))
		} else {
			attrs.putValue("Export-Package", exportedPackages.join(","))
		}
		val out = new ByteArrayOutputStream()
		manifest.write(out)
		val in = new ByteArrayInputStream(out.toByteArray)
		manifestFile.setContents(new BufferedInputStream(in), true, true, null)
	}
}